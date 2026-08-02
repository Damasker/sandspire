extends Control
## Skirmish lobby: factions, difficulty, map (post-MVP).

signal start_requested(player: String, enemy: String, difficulty: String, map_id: String)
signal cancelled

const FACTIONS := ["aureate", "ashveil", "coilward"]
const MAPS := [
	{"id": "ridge", "label": "Ridge (classic)"},
	{"id": "canyon", "label": "Canyon (map 2)"},
]

@onready var _panel: ColorRect = $Panel
@onready var _player: OptionButton = $Panel/PlayerFaction
@onready var _enemy: OptionButton = $Panel/EnemyFaction
@onready var _diff: OptionButton = $Panel/Difficulty
@onready var _map: OptionButton = $Panel/MapPick
@onready var _start: Button = $Panel/Start
@onready var _cancel: Button = $Panel/Cancel
@onready var _summary: Label = $Panel/Summary


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fill_factions(_player, "aureate")
	_fill_factions(_enemy, "ashveil")
	_diff.clear()
	_diff.add_item("Easy", 0)
	_diff.add_item("Normal", 1)
	_diff.add_item("Hard", 2)
	_diff.select(1)
	_map.clear()
	for i in MAPS.size():
		_map.add_item(str(MAPS[i]["label"]), i)
	_map.select(0)
	_player.item_selected.connect(func(_i): _refresh_summary())
	_enemy.item_selected.connect(func(_i): _refresh_summary())
	_diff.item_selected.connect(func(_i): _refresh_summary())
	_map.item_selected.connect(func(_i): _refresh_summary())
	_start.pressed.connect(_on_start)
	_cancel.pressed.connect(_on_cancel)
	_refresh_summary()


func open_lobby() -> void:
	visible = true
	move_to_front()
	_refresh_summary()


func hide_lobby() -> void:
	visible = false


func _fill_factions(btn: OptionButton, default_id: String) -> void:
	btn.clear()
	var sel := 0
	for i in FACTIONS.size():
		var fid: String = FACTIONS[i]
		btn.add_item(FactionDatabase.display_name(fid), i)
		if fid == default_id:
			sel = i
	btn.select(sel)


func _faction_at(btn: OptionButton) -> String:
	var i := btn.selected
	if i < 0 or i >= FACTIONS.size():
		return "aureate"
	return FACTIONS[i]


func _map_id() -> String:
	var i := _map.selected
	if i < 0 or i >= MAPS.size():
		return "ridge"
	return str(MAPS[i]["id"])


func _diff_id() -> String:
	match _diff.selected:
		0:
			return "easy"
		2:
			return "hard"
		_:
			return "normal"


func _refresh_summary() -> void:
	var p := _faction_at(_player)
	var e := _faction_at(_enemy)
	var warn := ""
	if p == e:
		warn = "  (mirror match)"
	_summary.text = "%s vs %s · %s · %s%s" % [
		FactionDatabase.short_name(p),
		FactionDatabase.short_name(e),
		_diff_id(),
		_map_id(),
		warn,
	]


func _on_start() -> void:
	start_requested.emit(_faction_at(_player), _faction_at(_enemy), _diff_id(), _map_id())


func _on_cancel() -> void:
	hide_lobby()
	cancelled.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_cancel()
		get_viewport().set_input_as_handled()
