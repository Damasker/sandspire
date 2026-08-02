extends Node
## Data-driven mission / skirmish objectives (S13).
## Backward-compatible with M1: camp_destroyed, register_camp, is_camp_destroyed, completed.

signal camp_destroyed
signal mission_complete
signal mission_won(text: String)
signal mission_lost(text: String)
signal objectives_changed
signal briefing_ready(title: String, advisor: String, text: String)

var camp_alive: bool = true
var completed: bool = false
var failed: bool = false
var outcome_text: String = ""

var mission_id: String = ""
var mission_def: Dictionary = {}
var elapsed: float = 0.0

## id -> { def, done, progress, label }
var _objectives: Dictionary = {}
var _fails: Array = []
var _economy: Node
var _bound_buildings: Array = []
var _world_ready: bool = false


func _ready() -> void:
	var sk := get_parent().get_node_or_null("SkirmishConfig")
	if sk and str(sk.get("mission_id")) != "":
		load_mission(str(sk.mission_id))
	else:
		_setup_default_skirmish()
	call_deferred("_bind_world")


func _process(delta: float) -> void:
	if completed or failed or not _world_ready:
		return
	elapsed += delta
	_tick_objectives()
	_tick_fails()


func load_mission(id: String) -> bool:
	var path := "res://data/missions/%s.json" % id
	if not FileAccess.file_exists(path):
		push_warning("Mission: missing %s" % path)
		_setup_default_skirmish()
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Mission: bad JSON %s" % path)
		_setup_default_skirmish()
		return false
	mission_def = parsed
	mission_id = str(mission_def.get("id", id))
	_apply_skirmish_from_def()
	_apply_map_params()
	_build_trackers_from_def()
	completed = false
	failed = false
	camp_alive = true
	elapsed = 0.0
	outcome_text = ""
	var br: Dictionary = mission_def.get("briefing", {})
	if not br.is_empty():
		briefing_ready.emit(
			str(mission_def.get("title", mission_id)),
			str(br.get("advisor", "Advisor")),
			str(br.get("text", ""))
		)
	objectives_changed.emit()
	return true


func map_params() -> Dictionary:
	var m: Dictionary = mission_def.get("map", {})
	var p: Variant = m.get("params", {})
	return p if typeof(p) == TYPE_DICTIONARY else {}


func _apply_map_params() -> void:
	var params := map_params()
	var wm := get_parent().get_node_or_null("WorldMap")
	if wm == null:
		return
	if params.has("map_seed"):
		wm.map_seed = int(params["map_seed"])
	if params.has("map_layout") and "map_layout" in wm:
		wm.map_layout = str(params["map_layout"])
	var sk := get_parent().get_node_or_null("SkirmishConfig")
	if sk and str(mission_id) == "" and str(sk.map_id) != "":
		wm.map_seed = int(sk.map_seed)
		if "map_layout" in wm:
			wm.map_layout = str(sk.map_id)


func _apply_skirmish_from_def() -> void:
	var sk := get_parent().get_node_or_null("SkirmishConfig")
	if sk == null:
		return
	var pf := str(mission_def.get("player_faction", sk.player_faction))
	var ef := str(mission_def.get("enemy_faction", sk.enemy_faction))
	if sk.has_method("set_factions"):
		sk.set_factions(pf, ef)
	var diff := str(mission_def.get("difficulty", sk.difficulty))
	if sk.has_method("set_difficulty"):
		sk.set_difficulty(diff)


func _setup_default_skirmish() -> void:
	mission_id = ""
	var sk := get_parent().get_node_or_null("SkirmishConfig")
	var map_name := "ridge"
	var seed_v := 11042
	if sk:
		map_name = str(sk.map_id)
		seed_v = int(sk.map_seed)
	mission_def = {
		"id": "skirmish",
		"title": "Skirmish (%s)" % map_name,
		"map": {"params": {"map_seed": seed_v, "map_layout": map_name}},
		"win_text": "Victory — Enemy camp destroyed",
		"lose_text": "Defeat — Construction Yard lost",
		"objectives": [
			{
				"id": "destroy_camp",
				"type": "destroy",
				"group": "enemy_camp",
				"count": 1,
				"required": true,
				"label": "Destroy the enemy camp",
			}
		],
		"fail_conditions": [
			{
				"id": "lose_conyard",
				"type": "building_lost",
				"building_id": "b_conyard",
				"team": "player",
				"label": "Construction Yard destroyed",
			}
		],
	}
	_apply_map_params()
	_build_trackers_from_def()


func _build_trackers_from_def() -> void:
	_objectives.clear()
	_fails.clear()
	for o in mission_def.get("objectives", []):
		if typeof(o) != TYPE_DICTIONARY:
			continue
		var oid := str(o.get("id", "obj_%d" % _objectives.size()))
		_objectives[oid] = {
			"def": o,
			"done": false,
			"progress": 0.0,
			"label": str(o.get("label", oid)),
		}
	for f in mission_def.get("fail_conditions", []):
		if typeof(f) == TYPE_DICTIONARY:
			_fails.append(f)


func _bind_world() -> void:
	var main := get_parent()
	if main:
		_economy = main.get_node_or_null("Economy")
	_bind_camp()
	_bind_fail_buildings()
	if _economy and _economy.has_signal("credits_changed"):
		if not _economy.credits_changed.is_connected(_on_credits_changed):
			_economy.credits_changed.connect(_on_credits_changed)
	_world_ready = true
	_tick_objectives()


func _bind_camp() -> void:
	for b in get_tree().get_nodes_in_group("enemy_camp"):
		if b.has_signal("died") and not b.died.is_connected(_on_camp_died):
			b.died.connect(_on_camp_died)


func register_camp(building: Node) -> void:
	camp_alive = true
	if building.has_signal("died") and not building.died.is_connected(_on_camp_died):
		building.died.connect(_on_camp_died)
	_bind_fail_buildings()
	_tick_objectives()


func _bind_fail_buildings() -> void:
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b):
			continue
		if b in _bound_buildings:
			continue
		if b.has_signal("died") and not b.died.is_connected(_on_building_died):
			b.died.connect(_on_building_died)
			_bound_buildings.append(b)


func is_camp_destroyed() -> bool:
	return not camp_alive or get_tree().get_nodes_in_group("enemy_camp").is_empty()


func title() -> String:
	return str(mission_def.get("title", "Skirmish"))


func has_briefing() -> bool:
	var br: Dictionary = mission_def.get("briefing", {})
	return str(br.get("text", "")) != ""


func briefing_advisor() -> String:
	return str(mission_def.get("briefing", {}).get("advisor", "Advisor"))


func briefing_text() -> String:
	return str(mission_def.get("briefing", {}).get("text", ""))


func want_ai() -> bool:
	if mission_def.is_empty() or mission_id == "":
		return true
	return bool(mission_def.get("ai_enabled", true))


func want_worm() -> bool:
	if mission_def.is_empty() or mission_id == "":
		return true
	return bool(mission_def.get("worm_enabled", true))


func starting_credits() -> int:
	return int(mission_def.get("starting_credits", 0))


func objective_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for oid in _objectives.keys():
		var row: Dictionary = _objectives[oid]
		var d: Dictionary = row["def"]
		var mark := "[x]" if bool(row["done"]) else "[ ]"
		var req := "" if bool(d.get("required", true)) else " (opt)"
		var prog := ""
		var t := str(d.get("type", ""))
		if t == "harvest":
			prog = " %d/%d" % [int(row["progress"]), int(d.get("amount", 0))]
		elif t == "survive":
			prog = " %.0f/%d" % [float(row["progress"]), int(d.get("seconds", 0))]
		lines.append("%s %s%s%s" % [mark, str(row["label"]), prog, req])
	return lines


func get_progress_snapshot() -> Dictionary:
	var objs := {}
	for oid in _objectives.keys():
		var row: Dictionary = _objectives[oid]
		objs[oid] = {"done": bool(row["done"]), "progress": float(row["progress"])}
	return {
		"mission_id": mission_id,
		"elapsed": elapsed,
		"completed": completed,
		"failed": failed,
		"camp_alive": camp_alive,
		"objectives": objs,
	}


func apply_progress_snapshot(data: Dictionary) -> void:
	elapsed = float(data.get("elapsed", 0.0))
	completed = bool(data.get("completed", false))
	failed = bool(data.get("failed", false))
	camp_alive = bool(data.get("camp_alive", true))
	var objs: Dictionary = data.get("objectives", {})
	for oid in objs.keys():
		if not _objectives.has(oid):
			continue
		var snap: Dictionary = objs[oid]
		_objectives[oid]["done"] = bool(snap.get("done", false))
		_objectives[oid]["progress"] = float(snap.get("progress", 0.0))
	objectives_changed.emit()


func force_complete_for_tests() -> void:
	## Headless helper: mark all required objectives done and win.
	for oid in _objectives.keys():
		var row: Dictionary = _objectives[oid]
		if bool(row["def"].get("required", true)):
			row["done"] = true
	_check_win()


func _on_camp_died(_building: Node) -> void:
	camp_alive = false
	camp_destroyed.emit()
	_tick_objectives()


func _on_building_died(_building: Node) -> void:
	if completed or failed:
		return
	_tick_fails()
	if get_tree().get_nodes_in_group("enemy_camp").is_empty():
		camp_alive = false
		camp_destroyed.emit()
	_tick_objectives()


func _on_credits_changed(_credits: int) -> void:
	_tick_objectives()


func _tick_objectives() -> void:
	if completed or failed:
		return
	var changed := false
	for oid in _objectives.keys():
		var row: Dictionary = _objectives[oid]
		if bool(row["done"]):
			continue
		var d: Dictionary = row["def"]
		var t := str(d.get("type", ""))
		match t:
			"destroy":
				var group := str(d.get("group", "enemy_camp"))
				var need := int(d.get("count", 1))
				var alive := get_tree().get_nodes_in_group(group).size()
				# Progress = how many of `need` cleared (group empty ⇒ fully done).
				row["progress"] = float(need if alive == 0 else maxi(0, need - alive))
				if alive == 0:
					row["done"] = true
					changed = true
					if group == "enemy_camp":
						camp_alive = false
			"harvest":
				var need_h := float(d.get("amount", 0))
				var earned := 0.0
				if _economy:
					earned = float(_economy.get("lifetime_earned"))
				row["progress"] = earned
				if earned >= need_h:
					row["done"] = true
					changed = true
			"survive":
				var need_s := float(d.get("seconds", 0))
				row["progress"] = elapsed
				if elapsed >= need_s:
					row["done"] = true
					changed = true
			_:
				pass
	if changed:
		objectives_changed.emit()
	_check_win()


func _tick_fails() -> void:
	if completed or failed:
		return
	for f in _fails:
		var t := str(f.get("type", ""))
		match t:
			"building_lost":
				var bid := str(f.get("building_id", ""))
				var team_name := str(f.get("team", "player"))
				var team := GameConstants.Team.PLAYER if team_name == "player" else GameConstants.Team.ENEMY
				if not _team_has_building(team, bid):
					_fail(str(mission_def.get("lose_text", "Defeat")))
					return
			"timeout":
				var secs := float(f.get("seconds", 0))
				if secs > 0.0 and elapsed >= secs:
					_fail(str(mission_def.get("lose_text", "Defeat — time expired")))
					return


func _team_has_building(team: int, building_id: String) -> bool:
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b) or b.get("alive") == false:
			continue
		if int(b.get("team")) != team:
			continue
		if str(b.get("building_id")) == building_id:
			return true
	return false


func _check_win() -> void:
	if completed or failed:
		return
	if _objectives.is_empty():
		return
	for oid in _objectives.keys():
		var row: Dictionary = _objectives[oid]
		if bool(row["def"].get("required", true)) and not bool(row["done"]):
			return
	_win(str(mission_def.get("win_text", "Victory")))


func _win(text: String) -> void:
	if completed or failed:
		return
	completed = true
	outcome_text = text
	mission_complete.emit()
	mission_won.emit(text)


func _fail(text: String) -> void:
	if completed or failed:
		return
	failed = true
	outcome_text = text
	mission_lost.emit(text)
