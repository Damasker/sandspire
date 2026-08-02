extends Node
## Skirmish / campaign stub (S13–S14).
## --player=… --enemy=… --difficulty=… --mission=… --campaign=rise_of_sand
## --campaign-menu → opens campaign picker
## Env: SANDSPIRE_PLAYER / ENEMY / DIFFICULTY / MISSION / CAMPAIGN

const CampaignDB := preload("res://scripts/campaign_db.gd")

signal factions_changed(player_faction: String, enemy_faction: String)
signal difficulty_changed(difficulty: String)
signal mission_changed(mission_id: String)

var player_faction: String = "aureate"
var enemy_faction: String = "ashveil"
var difficulty: String = "normal"
var mission_id: String = ""
var campaign_id: String = ""
var want_campaign_menu: bool = false

const DIFFICULTIES := ["easy", "normal", "hard"]


func _ready() -> void:
	_parse()
	if want_campaign_menu:
		call_deferred("_goto_campaign_menu")
		return
	if campaign_id != "" and mission_id == "":
		mission_id = CampaignDB.next_playable(campaign_id)
	elif campaign_id != "" and mission_id != "":
		CampaignDB.ensure_progress(campaign_id)
		if not CampaignDB.is_unlocked(campaign_id, mission_id):
			push_warning("SkirmishConfig: mission %s locked; using next playable" % mission_id)
			mission_id = CampaignDB.next_playable(campaign_id)
	factions_changed.emit(player_faction, enemy_faction)
	difficulty_changed.emit(difficulty)
	mission_changed.emit(mission_id)


func _goto_campaign_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/campaign_menu.tscn")


func _parse() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for a in OS.get_cmdline_args():
		args.append(a)
	for raw in args:
		var s := String(raw).strip_edges()
		if s.begins_with("--"):
			s = s.substr(2)
		if s == "campaign-menu" or s == "campaign_menu":
			want_campaign_menu = true
		elif s.begins_with("player_faction=") or s.begins_with("player="):
			player_faction = s.get_slice("=", 1).to_lower()
		elif s.begins_with("enemy_faction=") or s.begins_with("enemy="):
			enemy_faction = s.get_slice("=", 1).to_lower()
		elif s.begins_with("difficulty=") or s.begins_with("diff="):
			difficulty = s.get_slice("=", 1).to_lower()
		elif s.begins_with("mission=") or s.begins_with("mission_id="):
			mission_id = s.get_slice("=", 1).strip_edges()
		elif s.begins_with("campaign=") or s.begins_with("campaign_id="):
			campaign_id = s.get_slice("=", 1).strip_edges()
	var env_p := OS.get_environment("SANDSPIRE_PLAYER")
	var env_e := OS.get_environment("SANDSPIRE_ENEMY")
	var env_d := OS.get_environment("SANDSPIRE_DIFFICULTY")
	var env_m := OS.get_environment("SANDSPIRE_MISSION")
	var env_c := OS.get_environment("SANDSPIRE_CAMPAIGN")
	var env_menu := OS.get_environment("SANDSPIRE_CAMPAIGN_MENU")
	if env_p != "":
		player_faction = env_p.to_lower()
	if env_e != "":
		enemy_faction = env_e.to_lower()
	if env_d != "":
		difficulty = env_d.to_lower()
	if env_m != "":
		mission_id = env_m.strip_edges()
	if env_c != "":
		campaign_id = env_c.strip_edges()
	if env_menu == "1" or env_menu.to_lower() == "true":
		want_campaign_menu = true
	if not FactionDatabase.all_ids().has(player_faction):
		player_faction = "aureate"
	if not FactionDatabase.all_ids().has(enemy_faction):
		enemy_faction = "ashveil"
	if difficulty not in DIFFICULTIES:
		difficulty = "normal"
	if campaign_id != "" and CampaignDB.load_campaign(campaign_id).is_empty():
		push_warning("SkirmishConfig: unknown campaign '%s'" % campaign_id)
		campaign_id = ""
	if mission_id != "" and not FileAccess.file_exists("res://data/missions/%s.json" % mission_id):
		push_warning("SkirmishConfig: unknown mission '%s'" % mission_id)
		mission_id = ""


func faction_for_team(team: int) -> String:
	if team == GameConstants.Team.ENEMY:
		return enemy_faction
	return player_faction


func set_factions(player_id: String, enemy_id: String) -> void:
	player_faction = player_id.to_lower()
	enemy_faction = enemy_id.to_lower()
	factions_changed.emit(player_faction, enemy_faction)


func set_difficulty(diff_id: String) -> void:
	difficulty = diff_id.to_lower()
	if difficulty not in DIFFICULTIES:
		difficulty = "normal"
	difficulty_changed.emit(difficulty)
