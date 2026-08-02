extends Node
## Persisted UX options (S15). Path: user://options.json

signal options_changed

const PATH := "user://options.json"
const Locale := preload("res://scripts/locale.gd")

var scroll_speed: float = 600.0
var edge_scroll: bool = true
var master_volume: float = 0.8
var sfx_volume: float = 0.7
var ui_scale: float = 1.0
var locale_code: String = "en"


func _ready() -> void:
	load_options()
	# Defer until Main @onready refs exist.
	call_deferred("apply")


func load_options() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed
	scroll_speed = clampf(float(d.get("scroll_speed", scroll_speed)), 200.0, 1400.0)
	edge_scroll = bool(d.get("edge_scroll", edge_scroll))
	master_volume = clampf(float(d.get("master_volume", master_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(d.get("sfx_volume", sfx_volume)), 0.0, 1.0)
	ui_scale = clampf(float(d.get("ui_scale", ui_scale)), 0.85, 1.5)
	locale_code = str(d.get("locale", locale_code)).to_lower()
	if locale_code not in ["en", "ru"]:
		locale_code = "en"


func save_options() -> bool:
	var data := {
		"scroll_speed": scroll_speed,
		"edge_scroll": edge_scroll,
		"master_volume": master_volume,
		"sfx_volume": sfx_volume,
		"ui_scale": ui_scale,
		"locale": locale_code,
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


func apply() -> void:
	Locale.set_locale(locale_code)
	var main := get_parent()
	if main == null:
		options_changed.emit()
		return
	var cam := main.get_node_or_null("RtsCamera")
	if cam:
		cam.pan_speed = scroll_speed
		cam.edge_scroll_enabled = edge_scroll
	var sfx := main.get_node_or_null("SfxBus")
	if sfx and sfx.has_method("apply_volumes"):
		sfx.apply_volumes(master_volume, sfx_volume)
	if main.has_method("apply_ui_scale"):
		main.apply_ui_scale(ui_scale)
	if main.has_method("refresh_locale_hud"):
		main.refresh_locale_hud()
	options_changed.emit()


func set_from_ui(
	p_scroll: float,
	p_edge: bool,
	p_master: float,
	p_sfx: float,
	p_scale: float,
	p_locale: String
) -> void:
	scroll_speed = clampf(p_scroll, 200.0, 1400.0)
	edge_scroll = p_edge
	master_volume = clampf(p_master, 0.0, 1.0)
	sfx_volume = clampf(p_sfx, 0.0, 1.0)
	ui_scale = clampf(p_scale, 0.85, 1.5)
	locale_code = p_locale.to_lower()
	if locale_code not in ["en", "ru"]:
		locale_code = "en"
	save_options()
	apply()
