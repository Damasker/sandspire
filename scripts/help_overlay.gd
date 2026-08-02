extends Control
## Hotkey help overlay — ? / F1 (S15).

const Locale := preload("res://scripts/locale.gd")

@onready var _title: Label = $Panel/Title
@onready var _body: Label = $Panel/Body
@onready var _hint: Label = $Panel/Hint


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	refresh_text()


func refresh_text() -> void:
	_title.text = Locale.t("help_title")
	_body.text = "\n".join([
		"WASD / arrows — pan camera",
		"Wheel — zoom",
		"LMB — select   Shift+LMB — add",
		"RMB — move / attack-move",
		"A — attack-move arm   S — stop   H — hold",
		"1–6 — place buildings",
		"Q–Y — produce (selected factory/barracks)",
		"Esc / RMB — cancel ghost build",
		"B — advisor briefing",
		"O — options",
		"F5 — quicksave   F9 — quickload",
		"? / F1 — this help",
	])
	_hint.text = Locale.t("close") + " — Esc / ? / F1 / click"


func show_help() -> void:
	refresh_text()
	visible = true
	move_to_front()


func hide_help() -> void:
	visible = false


func toggle() -> void:
	if visible:
		hide_help()
	else:
		show_help()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		hide_help()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1 or event.unicode == 63 or (event.keycode == KEY_SLASH and event.shift_pressed):
			hide_help()
			get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide_help()
