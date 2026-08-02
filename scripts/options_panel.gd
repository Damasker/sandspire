extends Control
## Options stub: scroll, edge scroll, volume, locale, UI scale (S15).

const Locale := preload("res://scripts/locale.gd")

@onready var _title: Label = $Panel/Title
@onready var _scroll: HSlider = $Panel/ScrollSpeed
@onready var _edge: CheckButton = $Panel/EdgeScroll
@onready var _master: HSlider = $Panel/MasterVolume
@onready var _sfx: HSlider = $Panel/SfxVolume
@onready var _scale: HSlider = $Panel/UiScale
@onready var _locale: OptionButton = $Panel/Locale
@onready var _lbl_scroll: Label = $Panel/LblScroll
@onready var _lbl_master: Label = $Panel/LblMaster
@onready var _lbl_sfx: Label = $Panel/LblSfx
@onready var _lbl_scale: Label = $Panel/LblScale
@onready var _lbl_lang: Label = $Panel/LblLang
@onready var _apply: Button = $Panel/Apply
@onready var _close: Button = $Panel/CloseBtn


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_locale.clear()
	_locale.add_item("English", 0)
	_locale.add_item("Русский", 1)
	_apply.pressed.connect(_on_apply)
	_close.pressed.connect(hide_panel)
	refresh_labels()


func refresh_labels() -> void:
	_title.text = Locale.t("options_title")
	_lbl_scroll.text = Locale.t("scroll_speed")
	_edge.text = Locale.t("edge_scroll")
	_lbl_master.text = Locale.t("master_volume")
	_lbl_sfx.text = Locale.t("sfx_volume")
	_lbl_scale.text = Locale.t("ui_scale")
	_lbl_lang.text = Locale.t("language")
	_apply.text = Locale.t("apply")
	_close.text = Locale.t("close")


func open_from_options(opt: Node) -> void:
	if opt == null:
		return
	_scroll.min_value = 200
	_scroll.max_value = 1400
	_scroll.step = 50
	_scroll.value = float(opt.scroll_speed)
	_edge.button_pressed = bool(opt.edge_scroll)
	_master.min_value = 0
	_master.max_value = 100
	_master.value = float(opt.master_volume) * 100.0
	_sfx.min_value = 0
	_sfx.max_value = 100
	_sfx.value = float(opt.sfx_volume) * 100.0
	_scale.min_value = 85
	_scale.max_value = 150
	_scale.step = 5
	_scale.value = float(opt.ui_scale) * 100.0
	_locale.select(1 if str(opt.locale_code) == "ru" else 0)
	refresh_labels()
	visible = true
	move_to_front()


func hide_panel() -> void:
	visible = false


func toggle(opt: Node) -> void:
	if visible:
		hide_panel()
	else:
		open_from_options(opt)


func _on_apply() -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	var opt := main.get_node_or_null("GameOptions")
	if opt == null:
		return
	var loc := "ru" if _locale and _locale.selected == 1 else "en"
	opt.set_from_ui(
		float(_scroll.value) if _scroll else 600.0,
		_edge.button_pressed if _edge else true,
		float(_master.value) / 100.0 if _master else 0.8,
		float(_sfx.value) / 100.0 if _sfx else 0.7,
		float(_scale.value) / 100.0 if _scale else 1.0,
		loc
	)
	refresh_labels()
	var sfx := main.get_node_or_null("SfxBus")
	if sfx and sfx.has_method("play_ui"):
		sfx.play_ui("ok")
	var help := main.get_node_or_null("HUD/HelpOverlay")
	if help and help.has_method("refresh_text"):
		help.refresh_text()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		hide_panel()
		get_viewport().set_input_as_handled()
