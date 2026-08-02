extends Control
## Main menu — Campaign / Skirmish / Options / Quit (S16).

const Version := preload("res://scripts/version.gd")
const Locale := preload("res://scripts/locale.gd")

@onready var _title: Label = $Panel/Title
@onready var _version: Label = $Panel/Version
@onready var _campaign: Button = $Panel/Campaign
@onready var _skirmish: Button = $Panel/Skirmish
@onready var _options: Button = $Panel/Options
@onready var _quit: Button = $Panel/Quit
@onready var _hint: Label = $Panel/Hint
@onready var _options_panel: Control = $OptionsPanel
@onready var _game_options: Node = $GameOptions


func _ready() -> void:
	_title.text = "Sandspire"
	_version.text = Version.display_string()
	_campaign.pressed.connect(_on_campaign)
	_skirmish.pressed.connect(_on_skirmish)
	_options.pressed.connect(_on_options)
	_quit.pressed.connect(_on_quit)
	_hint.text = "Server 110 lab build · ? in-game for hotkeys"
	if _game_options and _game_options.has_method("apply"):
		_game_options.apply()


func _on_campaign() -> void:
	OS.set_environment("SANDSPIRE_CAMPAIGN", "rise_of_sand")
	OS.set_environment("SANDSPIRE_MISSION", "")
	var err := get_tree().change_scene_to_file("res://scenes/campaign_menu.tscn")
	if err != OK:
		push_error("MainMenu: failed to open campaign menu: %s" % err)


func _on_skirmish() -> void:
	OS.set_environment("SANDSPIRE_CAMPAIGN", "")
	OS.set_environment("SANDSPIRE_MISSION", "")
	var err := get_tree().change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("MainMenu: failed to open skirmish: %s" % err)


func _on_options() -> void:
	if _options_panel and _options_panel.has_method("toggle"):
		_options_panel.toggle(_game_options)


func _on_quit() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _options_panel and _options_panel.visible:
				_options_panel.hide_panel()
			else:
				_on_quit()
			get_viewport().set_input_as_handled()
