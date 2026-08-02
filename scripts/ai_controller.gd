extends Node
## Skirmish AI v1 — utility priorities: power → eco → produce → wave attacks.
## Profile: data/ai/normal.json (documented small start-credit boost only).

signal wave_launched(wave_index: int, army_size: int)
signal structure_built(building_id: String)
signal unit_queued(unit_id: String)

@export var team: int = GameConstants.Team.ENEMY
@export var profile_id: String = "normal"
@export var enabled: bool = true
@export var faction_id: String = "ashveil"

var waves_launched: int = 0
var combat_army_peak: int = 0
var buildings_built: int = 0

var _profile: Dictionary = {}
var _think_cd: float = 0.0
var _wave_cd: float = 8.0
var _world_map: Node2D
var _buildings_root: Node2D
var _units_root: Node2D
var _economy: Node
var _power: Node
var _pathfinder: Node
var _base_origin: Vector2i = Vector2i(34, 8)


func _ready() -> void:
	_load_profile()
	call_deferred("_bind")


func _load_profile() -> void:
	var path := "res://data/ai/%s.json" % profile_id
	if not FileAccess.file_exists(path):
		_profile = {
			"starting_credits": 450,
			"think_interval": 0.8,
			"wave_min_army": 3,
			"wave_cooldown": 40.0,
			"max_harvesters": 2,
			"prefer_factory": true,
		}
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) == TYPE_DICTIONARY:
		_profile = parsed
	else:
		_profile = {}


func _bind() -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	_world_map = main.get_node_or_null("WorldMap")
	_buildings_root = main.get_node_or_null("Buildings")
	_units_root = main.get_node_or_null("Units")
	_pathfinder = main.get_node_or_null("Pathfinder")
	var sk := main.get_node_or_null("SkirmishConfig")
	if sk and sk.has_method("faction_for_team"):
		faction_id = str(sk.faction_for_team(team))
	if team == GameConstants.Team.ENEMY:
		_economy = main.get_node_or_null("EnemyEconomy")
		_power = main.get_node_or_null("EnemyPowerGrid")
	else:
		_economy = main.get_node_or_null("Economy")
		_power = main.get_node_or_null("PowerGrid")
	_base_origin = _find_base_origin()
	var start_credits := int(_profile.get("starting_credits", 450))
	if _economy and _economy.credits < start_credits:
		_economy.add_credits(start_credits - _economy.credits)
	_think_cd = 0.2
	_wave_cd = 6.0


func _find_base_origin() -> Vector2i:
	for b in get_tree().get_nodes_in_group("enemy_camp"):
		if is_instance_valid(b):
			return Vector2i(
				int(b.global_position.x) / GameConstants.TILE_SIZE,
				int(b.global_position.y) / GameConstants.TILE_SIZE
			)
	for b in get_tree().get_nodes_in_group("conyards"):
		if is_instance_valid(b) and int(b.get("team")) == team:
			return Vector2i(
				int(b.global_position.x) / GameConstants.TILE_SIZE,
				int(b.global_position.y) / GameConstants.TILE_SIZE
			)
	return Vector2i(34, 8)


func _process(delta: float) -> void:
	if not enabled:
		return
	_think_cd -= delta
	_wave_cd = maxf(0.0, _wave_cd - delta)
	if _think_cd > 0.0:
		return
	_think_cd = float(_profile.get("think_interval", 0.8))
	_tick_economy_build()
	_tick_produce()
	_tick_wave()


func _count_buildings(building_id: String) -> int:
	var n := 0
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b) or b.get("alive") == false:
			continue
		if int(b.get("team")) != team:
			continue
		if str(b.get("building_id")) == building_id:
			n += 1
	return n


func _count_units(unit_id: String = "") -> int:
	var n := 0
	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u) or u.get("alive") == false:
			continue
		if int(u.get("team")) != team:
			continue
		if unit_id != "" and str(u.get("unit_id")) != unit_id:
			continue
		n += 1
	return n


func _count_harvesters() -> int:
	var n := 0
	for u in get_tree().get_nodes_in_group("harvesters"):
		if not is_instance_valid(u) or u.get("alive") == false:
			continue
		if int(u.get("team")) != team:
			continue
		n += 1
	return n


func _count_combat_army() -> int:
	var n := 0
	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u) or u.get("alive") == false:
			continue
		if int(u.get("team")) != team:
			continue
		var uid := str(u.get("unit_id"))
		if uid.contains("harvester") or u.is_in_group("harvesters"):
			continue
		if float(u.get("dps")) <= 0.0:
			continue
		n += 1
	combat_army_peak = maxi(combat_army_peak, n)
	return n


func _power_surplus() -> int:
	if _power == null:
		return 0
	if _power.has_method("recalculate"):
		_power.recalculate()
	return int(_power.get("surplus"))


func _tick_economy_build() -> void:
	if _count_buildings("b_conyard") <= 0 and _count_buildings("b_camp") <= 0:
		return
	# Treat camp as enough to bootstrap if no CY (prereq override via direct place)
	if _count_buildings("b_power") <= 0:
		if _try_place("b_power"):
			return
	if _count_buildings("b_refinery") <= 0 and _count_buildings("b_power") > 0:
		if _try_place("b_refinery"):
			return
	if _power_surplus() < 30 and _count_buildings("b_power") < 3:
		if _economy and _economy.can_afford(int(BuildingDatabase.get_building("b_power").get("cost", 300))):
			if _try_place("b_power"):
				return
	if bool(_profile.get("prefer_factory", true)):
		if _count_buildings("b_factory") <= 0 and _count_buildings("b_refinery") > 0:
			if _try_place("b_factory"):
				return
	if _count_buildings("b_barracks") <= 0 and _count_buildings("b_power") > 0:
		_try_place("b_barracks")


func _try_place(building_id: String) -> bool:
	var prereq_ok := BuildingDatabase.meets_prereqs(get_tree(), building_id, team)
	if not prereq_ok:
		# Camp counts as HQ for first Windtrap if ConYard absent
		if building_id == "b_power" and _count_buildings("b_camp") > 0:
			prereq_ok = true
		else:
			return false
	var def := BuildingDatabase.get_building(building_id)
	var cost := int(def.get("cost", 0))
	if _economy == null or not _economy.can_afford(cost):
		return false
	var fp := BuildingDatabase.footprint_of(building_id)
	var origin := _find_build_spot(fp)
	if origin.x < 0:
		return false
	if not _economy.try_spend(cost):
		return false
	var b := _spawn_building(building_id, origin, fp)
	if b == null:
		_economy.add_credits(cost)
		return false
	buildings_built += 1
	structure_built.emit(building_id)
	if building_id == "b_refinery" and _count_harvesters() < int(_profile.get("max_harvesters", 2)):
		_spawn_harvester_near(b)
	if _pathfinder and _pathfinder.has_method("rebuild_blocked"):
		_pathfinder.rebuild_blocked()
	if _power and _power.has_method("register_building"):
		_power.register_building(b)
	return true


func _find_build_spot(fp: Vector2i) -> Vector2i:
	if _world_map == null or _buildings_root == null:
		return Vector2i(-1, -1)
	# Spiral / scan near enemy rock base, prefer east plate
	for radius in range(0, 14):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius and radius > 0:
					continue
				var origin := Vector2i(_base_origin.x + dx, _base_origin.y + dy)
				if _is_valid_placement(origin, fp):
					return origin
	# Fallback: scan eastern rock plate
	for y in range(6, 16):
		for x in range(32, 42):
			var origin := Vector2i(x, y)
			if _is_valid_placement(origin, fp):
				return origin
	return Vector2i(-1, -1)


func _is_valid_placement(origin: Vector2i, fp: Vector2i) -> bool:
	if _world_map == null or not _world_map.can_place_footprint(origin, fp):
		return false
	var ts := GameConstants.TILE_SIZE
	var rect := Rect2(
		Vector2(origin.x * ts, origin.y * ts),
		Vector2(fp.x * ts, fp.y * ts)
	)
	for child in _buildings_root.get_children():
		if child.has_method("get_selection_rect") and rect.intersects(child.get_selection_rect()):
			return false
	return true


func _spawn_building(building_id: String, origin: Vector2i, fp: Vector2i) -> Node:
	var scene := preload("res://scenes/building.tscn")
	var b: StaticBody2D = scene.instantiate()
	b.building_id = building_id
	b.footprint = fp
	b.team = team
	b.team_color = Color(0.7, 0.22, 0.18)
	b.global_position = Vector2(
		origin.x * GameConstants.TILE_SIZE,
		origin.y * GameConstants.TILE_SIZE
	)
	_buildings_root.add_child(b)
	return b


func _spawn_harvester_near(refinery: Node) -> void:
	if _units_root == null:
		return
	var scene := preload("res://scenes/harvester.tscn")
	var h: CharacterBody2D = scene.instantiate()
	var hid := FactionDatabase.role_unit(faction_id, "harvester")
	h.unit_id = hid if hid != "" else "u_harvester"
	h.team = team
	h.team_color = Color(0.9, 0.45, 0.25)
	h.global_position = refinery.get_rally_position() if refinery.has_method("get_rally_position") else refinery.global_position + Vector2(40, 40)
	_units_root.add_child(h)


func _tick_produce() -> void:
	var max_h := int(_profile.get("max_harvesters", 2))
	var harv_id := FactionDatabase.role_unit(faction_id, "harvester")
	var tank_id := FactionDatabase.role_unit(faction_id, "tank")
	var quad_id := FactionDatabase.role_unit(faction_id, "quad")
	var inf_id := FactionDatabase.role_unit(faction_id, "infantry")
	if harv_id == "":
		harv_id = "u_harvester"
	if tank_id == "":
		tank_id = "u_tank"
	if quad_id == "":
		quad_id = "u_quad"
	if inf_id == "":
		inf_id = "u_infantry"
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b) or int(b.get("team")) != team:
			continue
		if b.get("alive") == false:
			continue
		var bid := str(b.get("building_id"))
		if bid == "b_refinery" and _count_harvesters() < max_h:
			if b.has_method("enqueue_unit") and b.enqueue_unit(harv_id, true):
				unit_queued.emit(harv_id)
		elif bid == "b_factory":
			var cost_tank := int(UnitDatabase.get_unit(tank_id).get("cost", 300))
			var uid := tank_id if (_economy and _economy.can_afford(cost_tank)) else quad_id
			if b.has_method("get_queue_snapshot") and b.get_queue_snapshot().size() >= 2:
				continue
			if b.has_method("enqueue_unit") and b.enqueue_unit(uid, true):
				unit_queued.emit(uid)
		elif bid == "b_barracks":
			if b.has_method("get_queue_snapshot") and b.get_queue_snapshot().size() >= 2:
				continue
			if b.has_method("enqueue_unit") and b.enqueue_unit(inf_id, true):
				unit_queued.emit(inf_id)


func _tick_wave() -> void:
	var need := int(_profile.get("wave_min_army", 3))
	var army := _count_combat_army()
	if army < need or _wave_cd > 0.0:
		return
	var target := _pick_player_target()
	if target == null:
		return
	var sent := 0
	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u) or int(u.get("team")) != team:
			continue
		if str(u.get("unit_id")).contains("harvester") or u.is_in_group("harvesters"):
			continue
		if float(u.get("dps")) <= 0.0:
			continue
		if u.has_method("command_attack"):
			u.command_attack(target)
			sent += 1
		elif u.has_method("command_attack_move"):
			u.command_attack_move(target.global_position)
			sent += 1
	if sent <= 0:
		return
	waves_launched += 1
	_wave_cd = float(_profile.get("wave_cooldown", 40.0))
	wave_launched.emit(waves_launched, sent)


func _pick_player_target() -> Node:
	var best: Node = null
	var best_pri := 999
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b) or b.get("alive") == false:
			continue
		if int(b.get("team")) != GameConstants.Team.PLAYER:
			continue
		var bid := str(b.get("building_id"))
		var pri := 5
		if bid == "b_conyard":
			pri = 0
		elif bid == "b_refinery":
			pri = 1
		elif bid == "b_factory" or bid == "b_barracks":
			pri = 2
		elif bid == "b_power":
			pri = 3
		if pri < best_pri:
			best_pri = pri
			best = b
	return best


## Smoke / test helpers
func force_think() -> void:
	_think_cd = 0.0


func set_profile_override(key: String, value: Variant) -> void:
	_profile[key] = value
