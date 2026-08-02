extends Control
## Simple campaign picker (S14). Launch: godot --path . res://scenes/campaign_menu.tscn
## Or: --campaign-menu / SANDSPIRE_CAMPAIGN_MENU=1 from main.

const CampaignDB := preload("res://scripts/campaign_db.gd")

@onready var _title: Label = $Panel/Title
@onready var _desc: Label = $Panel/Description
@onready var _list: ItemList = $Panel/MissionList
@onready var _status: Label = $Panel/Status
@onready var _play: Button = $Panel/PlayButton
@onready var _reset: Button = $Panel/ResetButton

var _campaign_id: String = "rise_of_sand"
var _mission_ids: PackedStringArray = PackedStringArray()
var _back: Button


func _ready() -> void:
	var env_c := OS.get_environment("SANDSPIRE_CAMPAIGN")
	if env_c != "":
		_campaign_id = env_c
	for a in OS.get_cmdline_args():
		var s := String(a)
		if s.begins_with("--"):
			s = s.substr(2)
		if s.begins_with("campaign="):
			_campaign_id = s.get_slice("=", 1)
	if _play:
		_play.pressed.connect(_on_play)
	if _reset:
		_reset.pressed.connect(_on_reset)
	if _list:
		_list.item_activated.connect(func(_i): _on_play())
	_ensure_back_button()
	_refresh()


func _ensure_back_button() -> void:
	var panel := get_node_or_null("Panel")
	if panel == null:
		return
	_back = panel.get_node_or_null("BackButton") as Button
	if _back == null:
		_back = Button.new()
		_back.name = "BackButton"
		_back.text = "Back to menu"
		_back.position = Vector2(420, 450)
		_back.size = Vector2(160, 36)
		panel.add_child(_back)
	_back.pressed.connect(_on_back)


func _on_back() -> void:
	var err := get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	if err != OK:
		push_error("CampaignMenu: back failed: %s" % err)


func _refresh() -> void:
	var camp := CampaignDB.load_campaign(_campaign_id)
	if camp.is_empty():
		_title.text = "Campaign missing"
		_desc.text = _campaign_id
		return
	CampaignDB.ensure_progress(_campaign_id)
	_title.text = str(camp.get("title", _campaign_id))
	_desc.text = str(camp.get("description", ""))
	_mission_ids = CampaignDB.mission_ids(camp)
	_list.clear()
	var select_idx := 0
	var next_id := CampaignDB.next_playable(_campaign_id)
	for i in _mission_ids.size():
		var mid := _mission_ids[i]
		var def := CampaignDB.load_mission_def(mid)
		var unlocked := CampaignDB.is_unlocked(_campaign_id, mid)
		var done := CampaignDB.is_completed(_campaign_id, mid)
		var mark := "✓" if done else ("•" if unlocked else "🔒")
		var label := "%s %d. %s" % [mark, i + 1, str(def.get("title", mid))]
		_list.add_item(label)
		_list.set_item_disabled(i, not unlocked)
		if mid == next_id:
			select_idx = i
	if _list.item_count > 0:
		_list.select(select_idx)
	_status.text = "Next: %s  |  Enter/Play launches mission" % next_id


func _on_play() -> void:
	var idxs := _list.get_selected_items()
	if idxs.is_empty():
		return
	var mid := _mission_ids[idxs[0]]
	if not CampaignDB.is_unlocked(_campaign_id, mid):
		_status.text = "Mission locked"
		return
	OS.set_environment("SANDSPIRE_CAMPAIGN", _campaign_id)
	OS.set_environment("SANDSPIRE_MISSION", mid)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_reset() -> void:
	CampaignDB.reset_campaign_progress(_campaign_id)
	_status.text = "Progress reset"
	_refresh()
