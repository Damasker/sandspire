extends StaticBody2D
## Structure with HP, team, power-aware production queue.

signal selected_changed(selected: bool)
signal queue_changed(queue: Array)
signal unit_produced(unit_id: String)
signal died(building: Node)
signal damaged(hp: float, max_hp: float)

@export var building_id: String = "b_refinery"
@export var footprint: Vector2i = Vector2i(3, 2)
@export var team_color: Color = Color(0.55, 0.45, 0.25)
@export var team: int = GameConstants.Team.PLAYER

const MAX_QUEUE := 5

var selected: bool = false
var alive: bool = true
var hp: float = 500.0
var max_hp: float = 500.0
var armor_name: String = "medium"
var power_draw: int = 0  # negative consume, positive produce (from data)
var vision_tiles: int = 6
var turret_dps: float = 0.0
var turret_range: float = 0.0
var _prod_rate_mult: float = 1.0
var _turret_cd: float = 0.0
var _turret_target: Node = null
var _size_px: Vector2 = Vector2.ZERO
var _queue: Array[Dictionary] = []
var _units_root: Node2D
var _economy: Node
var _power: Node


func _ready() -> void:
	var def := BuildingDatabase.get_building(building_id)
	footprint = BuildingDatabase.footprint_of(building_id)
	_size_px = Vector2(
		footprint.x * GameConstants.TILE_SIZE,
		footprint.y * GameConstants.TILE_SIZE
	)
	max_hp = float(def.get("hp", 500.0))
	hp = max_hp
	armor_name = str(def.get("armor", "medium"))
	power_draw = int(def.get("power", 0))
	vision_tiles = int(def.get("vision_tiles", 6))
	if building_id == "b_turret":
		turret_dps = float(def.get("dps", 18.0))
		if def.has("range_px"):
			turret_range = float(def["range_px"])
		else:
			turret_range = GameConstants.range_px(str(def.get("range", "med")))
	if def.has("color"):
		var c: Variant = def["color"]
		if typeof(c) == TYPE_ARRAY and c.size() >= 3:
			team_color = Color(float(c[0]), float(c[1]), float(c[2]))
	add_to_group("buildings")
	add_to_group("selectable")
	add_to_group("damageable")
	if team == GameConstants.Team.ENEMY:
		add_to_group("team_enemy")
		team_color = Color(0.7, 0.22, 0.18)
	else:
		add_to_group("team_player")
	match building_id:
		"b_refinery":
			add_to_group("refineries")
			add_to_group("producers")
		"b_barracks", "b_factory":
			add_to_group("producers")
		"b_conyard":
			add_to_group("conyards")
		"b_camp":
			add_to_group("enemy_camp")
		"b_power":
			add_to_group("power_plants")
		"b_turret":
			add_to_group("turrets")
		"b_radar":
			add_to_group("radars")
			add_to_group("producers")
		"b_silo":
			add_to_group("silos")
	_apply_faction_building_mods()
	var shape := RectangleShape2D.new()
	shape.size = _size_px
	$CollisionShape2D.shape = shape
	$CollisionShape2D.position = _size_px * 0.5
	_bind_refs()
	call_deferred("_bind_refs")
	call_deferred("_register_power")
	queue_redraw()


func _apply_faction_building_mods() -> void:
	var mods := FactionDatabase.building_mods(_faction_id(), building_id)
	if mods.is_empty():
		return
	if mods.has("hp"):
		max_hp = float(mods["hp"])
		hp = max_hp
	if mods.has("armor"):
		armor_name = str(mods["armor"])
	if mods.has("dps"):
		turret_dps = float(mods["dps"])
	if mods.has("range_px"):
		turret_range = float(mods["range_px"])
	if mods.has("prod_rate_mult"):
		_prod_rate_mult = float(mods["prod_rate_mult"])


func _bind_refs() -> void:
	var main := get_tree().current_scene
	if main == null:
		var p := get_parent()
		if p:
			main = p.get_parent()
	if main == null:
		return
	_units_root = main.get_node_or_null("Units")
	if team == GameConstants.Team.ENEMY:
		_economy = main.get_node_or_null("EnemyEconomy")
		_power = main.get_node_or_null("EnemyPowerGrid")
	else:
		_economy = main.get_node_or_null("Economy")
		_power = main.get_node_or_null("PowerGrid")


func _ensure_refs() -> void:
	if _economy == null or _units_root == null or _power == null:
		_bind_refs()


func _register_power() -> void:
	_ensure_refs()
	if _power and _power.has_method("register_building"):
		_power.register_building(self)
	elif _power and _power.has_method("recalculate"):
		_power.recalculate()


func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	selected_changed.emit(selected)
	queue_redraw()


func get_unload_position() -> Vector2:
	return global_position + Vector2(_size_px.x * 0.5, _size_px.y + 8.0)


func get_rally_position() -> Vector2:
	return global_position + Vector2(_size_px.x * 0.5, _size_px.y + 24.0)


func get_selection_rect() -> Rect2:
	return Rect2(global_position, _size_px)


func apply_damage(amount: float, from_team: int) -> void:
	if not alive or from_team == team:
		return
	var reduced := maxf(1.0, amount - GameConstants.armor_value(armor_name))
	hp -= reduced
	damaged.emit(hp, max_hp)
	queue_redraw()
	if hp <= 0.0:
		_die()


func _die() -> void:
	if not alive:
		return
	alive = false
	died.emit(self)
	if _power and _power.has_method("recalculate"):
		_power.call_deferred("recalculate")
	queue_free()


func get_produced_unit_ids() -> Array:
	var faction_id := _faction_id()
	var faction_list: Array = FactionDatabase.produces_for(faction_id, building_id)
	if not faction_list.is_empty():
		return faction_list
	var def := BuildingDatabase.get_building(building_id)
	var produces: Variant = def.get("produces", [])
	if typeof(produces) != TYPE_ARRAY:
		return []
	return produces


func _faction_id() -> String:
	var main := get_tree().current_scene
	if main:
		var sk := main.get_node_or_null("SkirmishConfig")
		if sk and sk.has_method("faction_for_team"):
			return str(sk.faction_for_team(team))
	return "aureate" if team == GameConstants.Team.PLAYER else "ashveil"


func get_queue_snapshot() -> Array:
	return _queue.duplicate(true)


func get_production_rate() -> float:
	_ensure_refs()
	var rate := 1.0
	if _power and _power.has_method("get_production_rate"):
		rate = float(_power.get_production_rate())
	return rate * _prod_rate_mult


func is_production_paused() -> bool:
	return get_production_rate() <= 0.0


func enqueue_unit(unit_id: String, spend: bool = true) -> bool:
	_ensure_refs()
	if _queue.size() >= MAX_QUEUE:
		return false
	if unit_id not in get_produced_unit_ids():
		return false
	var udef := UnitDatabase.get_unit(unit_id)
	var cost := int(udef.get("cost", 0))
	var build_time := float(udef.get("build_time", 3.0))
	if spend:
		if _economy == null or not _economy.try_spend(cost):
			return false
	_queue.append({"id": unit_id, "remaining": build_time})
	queue_changed.emit(get_queue_snapshot())
	queue_redraw()
	return true


func set_front_job_remaining(seconds: float) -> void:
	if _queue.is_empty():
		return
	_queue[0]["remaining"] = maxf(0.0, seconds)
	queue_changed.emit(get_queue_snapshot())
	queue_redraw()


func _process(delta: float) -> void:
	if not alive:
		return
	if building_id == "b_turret" and turret_dps > 0.0:
		_tick_turret(delta)
	if _queue.is_empty():
		return
	var rate := get_production_rate()
	if rate <= 0.0:
		queue_redraw()
		return
	var job: Dictionary = _queue[0]
	job["remaining"] = float(job["remaining"]) - delta * rate
	_queue[0] = job
	if float(job["remaining"]) <= 0.0:
		var uid: String = str(job["id"])
		_queue.remove_at(0)
		_spawn_unit(uid)
		unit_produced.emit(uid)
		queue_changed.emit(get_queue_snapshot())
	queue_redraw()


func _tick_turret(delta: float) -> void:
	_turret_cd = maxf(0.0, _turret_cd - delta)
	if _turret_target != null and (
		not is_instance_valid(_turret_target)
		or _turret_target.get("alive") == false
		or get_selection_rect().get_center().distance_to(_aim(_turret_target)) > turret_range
	):
		_turret_target = null
	if _turret_target == null:
		_turret_target = _find_turret_target()
	if _turret_target == null or _turret_cd > 0.0:
		return
	_turret_target.apply_damage(turret_dps * 0.4, team)
	_turret_cd = 0.4
	queue_redraw()


func _aim(target: Node) -> Vector2:
	if target.has_method("get_selection_rect"):
		return target.get_selection_rect().get_center()
	return target.global_position


func _find_turret_target() -> Node:
	var origin := get_selection_rect().get_center()
	var best: Node = null
	var best_d := turret_range
	for node in get_tree().get_nodes_in_group("damageable"):
		if not is_instance_valid(node) or node == self:
			continue
		if int(node.get("team")) == team or node.get("alive") == false:
			continue
		# Prefer ground threats; still shoot air
		var d := origin.distance_to(_aim(node))
		if d < best_d:
			best_d = d
			best = node
	return best


func _spawn_unit(unit_id: String) -> void:
	_ensure_refs()
	if _units_root == null:
		return
	var scene: PackedScene
	if unit_id.ends_with("harvester"):
		scene = preload("res://scenes/harvester.tscn")
	else:
		scene = preload("res://scenes/unit.tscn")
	var u: CharacterBody2D = scene.instantiate()
	u.unit_id = unit_id
	u.team = team
	u.global_position = get_rally_position()
	_units_root.add_child(u)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _size_px), team_color, true)
	var border := Color(1, 1, 0.3) if selected else Color(0, 0, 0, 0.55)
	draw_rect(Rect2(Vector2.ZERO, _size_px), border, false, 2.0)
	if building_id == "b_refinery":
		var bay := Vector2(_size_px.x * 0.5 - 10.0, _size_px.y - 6.0)
		draw_rect(Rect2(bay, Vector2(20, 6)), Color(0.85, 0.7, 0.2), true)
	if building_id == "b_camp":
		draw_circle(_size_px * 0.5, 10.0, Color(0.95, 0.2, 0.15))
	if building_id == "b_turret":
		var barrel_col := Color(0.25, 0.55, 0.6) if turret_dps >= 28.0 else Color(0.3, 0.3, 0.35)
		draw_circle(_size_px * 0.5, 8.0, barrel_col)
		if _turret_target != null and is_instance_valid(_turret_target) and _turret_cd > 0.28:
			draw_line(_size_px * 0.5, to_local(_aim(_turret_target)), Color(1, 0.7, 0.3, 0.75), 1.5)
	if building_id == "b_radar":
		draw_arc(_size_px * 0.5, 14.0, 0, TAU, 24, Color(0.4, 0.9, 1.0, 0.8), 2.0)
	if building_id == "b_silo":
		draw_circle(_size_px * 0.5 + Vector2(0, -4), 10.0, Color(0.85, 0.7, 0.25))
		draw_rect(Rect2(_size_px * 0.5 - Vector2(6, 2), Vector2(12, 14)), Color(0.7, 0.55, 0.2), true)
	var ratio := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	draw_rect(Rect2(4, _size_px.y - 8, _size_px.x - 8, 4), Color(0, 0, 0, 0.5), true)
	draw_rect(Rect2(4, _size_px.y - 8, (_size_px.x - 8) * ratio, 4), Color(0.85, 0.25, 0.2), true)
	if not _queue.is_empty():
		var job: Dictionary = _queue[0]
		var udef := UnitDatabase.get_unit(str(job["id"]))
		var total := float(udef.get("build_time", 3.0))
		var rem := float(job["remaining"])
		var qratio := 1.0 - clampf(rem / maxf(total, 0.001), 0.0, 1.0)
		var bar_col := Color(1.0, 0.35, 0.2) if is_production_paused() else Color(0.3, 0.85, 1.0)
		draw_rect(Rect2(4, 4, (_size_px.x - 8.0) * qratio, 4), bar_col, true)
		if is_production_paused():
			draw_rect(Rect2(2, 2, _size_px.x - 4, 14), Color(0.6, 0.05, 0.05, 0.45), true)
