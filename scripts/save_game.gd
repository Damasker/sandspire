extends Node
## Pragmatic skirmish/mission save slots + autosave (S13).
## Paths: user://saves/slot_N.json, user://saves/autosave.json

signal save_finished(path: String, ok: bool)
signal load_finished(path: String, ok: bool)

const SAVE_VERSION := 1
const SLOT_COUNT := 3

## Set before reloading main scene to apply snapshot after spawn.
static var pending_load: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://saves"))


func slot_path(slot: int) -> String:
	return "user://saves/slot_%d.json" % clampi(slot, 0, SLOT_COUNT - 1)


func autosave_path() -> String:
	return "user://saves/autosave.json"


func save_slot(slot: int = 0) -> bool:
	return save_to(slot_path(slot))


func save_autosave() -> bool:
	return save_to(autosave_path())


func save_to(path: String) -> bool:
	var snap := capture_snapshot()
	if snap.is_empty():
		save_finished.emit(path, false)
		return false
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("SaveGame: cannot write %s" % path)
		save_finished.emit(path, false)
		return false
	f.store_string(JSON.stringify(snap, "\t"))
	f.close()
	save_finished.emit(path, true)
	return true


func load_slot(slot: int = 0) -> bool:
	return load_from(slot_path(slot))


func load_autosave() -> bool:
	return load_from(autosave_path())


func load_from(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_warning("SaveGame: missing %s" % path)
		load_finished.emit(path, false)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		load_finished.emit(path, false)
		return false
	pending_load = parsed
	var mid := str(parsed.get("mission_id", ""))
	var sk := get_parent().get_node_or_null("SkirmishConfig")
	if sk:
		if mid != "":
			sk.mission_id = mid
		sk.set_factions(str(parsed.get("player_faction", "aureate")), str(parsed.get("enemy_faction", "ashveil")))
		sk.set_difficulty(str(parsed.get("difficulty", "normal")))
	# Apply in-place without full scene reload when already in main.
	var ok := apply_pending_load()
	load_finished.emit(path, ok)
	return ok


func capture_snapshot() -> Dictionary:
	var main := get_parent()
	if main == null:
		return {}
	var sk: Node = main.get_node_or_null("SkirmishConfig")
	var mission: Node = main.get_node_or_null("Mission")
	var eco: Node = main.get_node_or_null("Economy")
	var eeco: Node = main.get_node_or_null("EnemyEconomy")
	var buildings_root: Node = main.get_node_or_null("Buildings")
	var units_root: Node = main.get_node_or_null("Units")
	var buildings: Array = []
	if buildings_root:
		for b in buildings_root.get_children():
			if not is_instance_valid(b) or b.get("alive") == false:
				continue
			var cell := Vector2i(
				int(b.global_position.x) / GameConstants.TILE_SIZE,
				int(b.global_position.y) / GameConstants.TILE_SIZE
			)
			buildings.append({
				"id": str(b.get("building_id")),
				"team": int(b.get("team")),
				"x": cell.x,
				"y": cell.y,
				"hp": float(b.get("hp")),
				"max_hp": float(b.get("max_hp")),
			})
	var units: Array = []
	if units_root:
		for u in units_root.get_children():
			if not is_instance_valid(u) or u.get("alive") == false:
				continue
			units.append({
				"id": str(u.get("unit_id")),
				"team": int(u.get("team")),
				"x": float(u.global_position.x),
				"y": float(u.global_position.y),
				"hp": float(u.get("hp")),
				"harvester": u.is_in_group("harvesters"),
				"cargo": int(u.get("cargo")) if "cargo" in u else 0,
			})
	var progress := {}
	if mission and mission.has_method("get_progress_snapshot"):
		progress = mission.get_progress_snapshot()
	return {
		"version": SAVE_VERSION,
		"mission_id": str(progress.get("mission_id", sk.mission_id if sk else "")),
		"player_faction": str(sk.player_faction) if sk else "aureate",
		"enemy_faction": str(sk.enemy_faction) if sk else "ashveil",
		"difficulty": str(sk.difficulty) if sk else "normal",
		"credits": int(eco.credits) if eco else 0,
		"lifetime_earned": int(eco.lifetime_earned) if eco else 0,
		"enemy_credits": int(eeco.credits) if eeco else 0,
		"progress": progress,
		"buildings": buildings,
		"units": units,
	}


func apply_pending_load() -> bool:
	if pending_load.is_empty():
		return false
	var data: Dictionary = pending_load
	pending_load = {}
	var main := get_parent()
	if main == null:
		return false
	var mission: Node = main.get_node_or_null("Mission")
	var eco: Node = main.get_node_or_null("Economy")
	var eeco: Node = main.get_node_or_null("EnemyEconomy")
	var power: Node = main.get_node_or_null("PowerGrid")
	var epower: Node = main.get_node_or_null("EnemyPowerGrid")
	var buildings_root: Node2D = main.get_node_or_null("Buildings")
	var units_root: Node2D = main.get_node_or_null("Units")
	var sk: Node = main.get_node_or_null("SkirmishConfig")

	var mid := str(data.get("mission_id", ""))
	if mission and mid != "" and mission.mission_id != mid and mission.has_method("load_mission"):
		mission.load_mission(mid)
	elif mission and mid == "" and mission.has_method("_setup_default_skirmish"):
		mission._setup_default_skirmish()

	if sk:
		sk.set_factions(str(data.get("player_faction", "aureate")), str(data.get("enemy_faction", "ashveil")))
		sk.set_difficulty(str(data.get("difficulty", "normal")))

	# Clear world entities
	if buildings_root:
		for c in buildings_root.get_children():
			c.queue_free()
	if units_root:
		for c in units_root.get_children():
			c.queue_free()
	# Wait one frame so frees apply — caller should await if needed; sync free for reliability
	if buildings_root:
		while buildings_root.get_child_count() > 0:
			var c := buildings_root.get_child(0)
			buildings_root.remove_child(c)
			c.free()
	if units_root:
		while units_root.get_child_count() > 0:
			var c := units_root.get_child(0)
			units_root.remove_child(c)
			c.free()

	var bscene := preload("res://scenes/building.tscn")
	var uscene := preload("res://scenes/unit.tscn")
	var hscene := preload("res://scenes/harvester.tscn")
	for spec in data.get("buildings", []):
		if typeof(spec) != TYPE_DICTIONARY:
			continue
		var b: StaticBody2D = bscene.instantiate()
		var bid := str(spec.get("id", "b_conyard"))
		b.building_id = bid
		b.footprint = BuildingDatabase.footprint_of(bid)
		b.team = int(spec.get("team", 0))
		b.team_color = Color(0.35, 0.45, 0.55) if b.team == GameConstants.Team.PLAYER else Color(0.7, 0.22, 0.18)
		b.global_position = Vector2(
			int(spec.get("x", 0)) * GameConstants.TILE_SIZE,
			int(spec.get("y", 0)) * GameConstants.TILE_SIZE
		)
		buildings_root.add_child(b)
		if float(spec.get("max_hp", 0)) > 0.0:
			b.max_hp = float(spec["max_hp"])
		if spec.has("hp"):
			b.hp = float(spec["hp"])
		if b.team == GameConstants.Team.PLAYER and power and power.has_method("register_building"):
			power.register_building(b)
		elif b.team == GameConstants.Team.ENEMY and epower and epower.has_method("register_building"):
			epower.register_building(b)
		if bid == "b_camp" and mission and mission.has_method("register_camp"):
			mission.register_camp(b)

	for spec in data.get("units", []):
		if typeof(spec) != TYPE_DICTIONARY:
			continue
		var uid := str(spec.get("id", "u_infantry"))
		var is_harv := bool(spec.get("harvester", uid.contains("harvester")))
		var u: CharacterBody2D = hscene.instantiate() if is_harv else uscene.instantiate()
		u.unit_id = uid
		u.team = int(spec.get("team", 0))
		u.global_position = Vector2(float(spec.get("x", 0)), float(spec.get("y", 0)))
		if u.team == GameConstants.Team.ENEMY:
			u.team_color = Color(0.85, 0.25, 0.2)
			if "auto_acquire" in u:
				u.auto_acquire = true
		units_root.add_child(u)
		if spec.has("hp") and "hp" in u:
			u.hp = float(spec["hp"])
		if is_harv and "cargo" in u:
			u.cargo = int(spec.get("cargo", 0))

	if eco:
		eco.credits = int(data.get("credits", 0))
		eco.lifetime_earned = int(data.get("lifetime_earned", eco.credits))
		eco.credits_changed.emit(eco.credits)
	if eeco:
		eeco.credits = int(data.get("enemy_credits", 0))
		eeco.credits_changed.emit(eeco.credits)

	if mission and mission.has_method("apply_progress_snapshot"):
		mission.apply_progress_snapshot(data.get("progress", {}))

	if power and power.has_method("recalculate"):
		power.recalculate()
	if epower and epower.has_method("recalculate"):
		epower.recalculate()
	var pathfinder := main.get_node_or_null("Pathfinder")
	if pathfinder and pathfinder.has_method("rebuild_blocked"):
		pathfinder.rebuild_blocked()
	var vision := main.get_node_or_null("VisionSystem")
	if vision and vision.has_method("update_vision"):
		vision.update_vision()
	return true


func has_slot(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))
