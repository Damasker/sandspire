class_name Unit
extends CharacterBody2D
## Selectable combat unit: path follow, attack-move, hold, stuck recovery.

signal selection_changed(selected: bool)
signal died(unit: Node)
signal damaged(hp: float, max_hp: float)

@export var unit_id: String = "u_trike"
@export var move_speed: float = 140.0
@export var radius: float = 12.0
@export var team_color: Color = Color(0.2, 0.55, 0.95)
@export var team: int = GameConstants.Team.PLAYER
@export var auto_acquire: bool = true

var selected: bool = false
var hp: float = 100.0
var max_hp: float = 100.0
var armor_name: String = "light"
var dps: float = 10.0
var attack_range: float = 120.0
var vision_tiles: int = 5
var alive: bool = true
var short_label: String = ""
var unit_accent: Color = Color(0.2, 0.55, 0.95)
var splash_radius: float = 0.0
var splash_ratio: float = 0.0
var flying: bool = false

var _target: Variant = null  # Vector2 or null — current waypoint
var _goal: Vector2 = Vector2.ZERO
var _has_goal: bool = false
var _waypoints: PackedVector2Array = PackedVector2Array()
var _wp_index: int = 0
var _attack_target: Node = null
var _def: Dictionary = {}
var _manual_move: bool = false
var _attack_move: bool = false
var _hold: bool = false
var _attack_ordered: bool = false
var _attack_cd: float = 0.0
var _acquire_cd: float = 0.0
var _repath_cd: float = 0.0
var _stuck_time: float = 0.0
var _vision: Node
var _pathfinder: Node


func _ready() -> void:
	_def = UnitDatabase.get_unit(unit_id)
	_apply_def()
	add_to_group("units")
	add_to_group("selectable")
	add_to_group("damageable")
	_apply_team_group()
	var shape := CircleShape2D.new()
	shape.radius = radius
	$CollisionShape2D.shape = shape
	call_deferred("_bind_systems")
	queue_redraw()


func _bind_systems() -> void:
	var main := get_tree().current_scene
	if main:
		_vision = main.get_node_or_null("VisionSystem")
		_pathfinder = main.get_node_or_null("Pathfinder")


func _apply_def() -> void:
	if _def.has("speed"):
		move_speed = float(_def["speed"])
	max_hp = float(_def.get("hp", max_hp))
	hp = max_hp
	armor_name = str(_def.get("armor", "light"))
	dps = float(_def.get("dps", 0.0))
	vision_tiles = int(_def.get("vision_tiles", 5))
	if _def.has("radius"):
		radius = float(_def["radius"])
	short_label = str(_def.get("label", unit_id.substr(2, 3).to_upper()))
	var c: Variant = _def.get("color", null)
	if typeof(c) == TYPE_ARRAY and c.size() >= 3:
		unit_accent = Color(float(c[0]), float(c[1]), float(c[2]))
		if team != GameConstants.Team.ENEMY:
			team_color = unit_accent
	var range_key := str(_def.get("range", "med"))
	if _def.has("range_px"):
		attack_range = float(_def["range_px"])
	else:
		attack_range = GameConstants.range_px(range_key)
	splash_radius = float(_def.get("splash_radius", 0.0))
	splash_ratio = float(_def.get("splash_ratio", 0.0))
	flying = bool(_def.get("flying", false))
	if flying:
		z_index = 25
		add_to_group("air_units")
	if dps <= 0.0:
		auto_acquire = false


func _apply_team_group() -> void:
	if team == GameConstants.Team.ENEMY:
		add_to_group("team_enemy")
		if team_color == Color(0.2, 0.55, 0.95):
			team_color = Color(0.85, 0.25, 0.2)
	else:
		add_to_group("team_player")


func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	selection_changed.emit(selected)
	queue_redraw()


func set_destination(world_pos: Vector2) -> void:
	_goal = world_pos
	_has_goal = true
	_stuck_time = 0.0
	_repath_cd = 0.0
	if flying:
		# Air ignores ground path blocks / building footprints
		_waypoints = PackedVector2Array([world_pos])
	else:
		if _pathfinder == null:
			_bind_systems()
		if _pathfinder and _pathfinder.has_method("find_path"):
			_waypoints = _pathfinder.find_path(global_position, world_pos)
		else:
			_waypoints = PackedVector2Array([world_pos])
	_wp_index = 0
	if _waypoints.is_empty():
		_target = world_pos
	else:
		_target = _waypoints[0]


func command_move(world_pos: Vector2) -> void:
	_manual_move = true
	_attack_move = false
	_hold = false
	_attack_ordered = false
	_attack_target = null
	set_destination(world_pos)


func command_attack_move(world_pos: Vector2) -> void:
	if not alive:
		return
	_manual_move = false
	_attack_move = true
	_hold = false
	_attack_ordered = false
	_attack_target = null
	set_destination(world_pos)


func command_stop() -> void:
	_manual_move = false
	_attack_move = false
	_hold = false
	_has_goal = false
	_attack_ordered = false
	_attack_target = null
	_waypoints.clear()
	_wp_index = 0
	_target = null
	velocity = Vector2.ZERO


func command_hold() -> void:
	command_stop()
	_hold = true


func command_attack(target: Node) -> void:
	if not alive or dps <= 0.0:
		return
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("apply_damage"):
		return
	if int(target.get("team")) == team:
		return
	_manual_move = false
	_attack_move = false
	_hold = false
	_attack_ordered = true
	_attack_target = target
	_waypoints.clear()
	_target = null


func clear_move_target() -> void:
	_target = null
	_waypoints.clear()
	_manual_move = false
	_attack_move = false
	velocity = Vector2.ZERO


func get_selection_rect() -> Rect2:
	return Rect2(global_position - Vector2(radius, radius), Vector2(radius * 2, radius * 2))


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
	queue_free()


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_acquire_cd = maxf(0.0, _acquire_cd - delta)
	_repath_cd = maxf(0.0, _repath_cd - delta)

	if _hold:
		_tick_hold(delta)
		queue_redraw()
		return

	if _manual_move:
		if _move_toward_target(delta):
			_manual_move = false
		queue_redraw()
		return

	if _attack_target != null and not is_instance_valid(_attack_target):
		_attack_target = null
		_attack_ordered = false

	if (
		_attack_target != null
		and not _attack_ordered
		and team == GameConstants.Team.PLAYER
		and not _is_target_visible(_attack_target)
	):
		_attack_target = null

	# Attack-move: acquire while walking to goal
	if _attack_move and _attack_target == null and auto_acquire and dps > 0.0 and _acquire_cd <= 0.0:
		_acquire_cd = 0.25
		_attack_target = _find_nearest_enemy(attack_range * 1.35)
		_attack_ordered = false

	if _attack_target == null and not _attack_move and auto_acquire and dps > 0.0 and _acquire_cd <= 0.0:
		_acquire_cd = 0.25
		_attack_target = _find_nearest_enemy(attack_range * 1.35)
		_attack_ordered = false

	if _attack_target != null:
		_tick_combat(delta)
	elif _attack_move:
		if _move_toward_target(delta):
			_attack_move = false
	else:
		_move_toward_target(delta)
	queue_redraw()


func _tick_hold(delta: float) -> void:
	velocity = Vector2.ZERO
	if dps <= 0.0:
		return
	if _attack_target != null and not is_instance_valid(_attack_target):
		_attack_target = null
	if _attack_target == null and auto_acquire and _acquire_cd <= 0.0:
		_acquire_cd = 0.25
		_attack_target = _find_nearest_enemy(attack_range)
	if _attack_target == null:
		return
	var aim := _target_aim_point(_attack_target)
	if global_position.distance_to(aim) > attack_range:
		_attack_target = null
		return
	if _attack_cd <= 0.0:
		_deal_shot(_attack_target, dps * 0.4)
		_attack_cd = 0.4


func _tick_combat(delta: float) -> void:
	var aim := _target_aim_point(_attack_target)
	var dist := global_position.distance_to(aim)
	if dist > attack_range * 0.92:
		if _repath_cd <= 0.0:
			_repath_cd = 0.45
			set_destination(aim)
		_move_toward_target(delta)
		return
	_target = null
	_waypoints.clear()
	velocity = Vector2.ZERO
	if _attack_cd <= 0.0:
		_deal_shot(_attack_target, dps * 0.4)
		_attack_cd = 0.4
		queue_redraw()


func _deal_shot(primary: Node, amount: float) -> void:
	if primary == null or not is_instance_valid(primary):
		return
	primary.apply_damage(amount, team)
	if splash_radius <= 0.0 or splash_ratio <= 0.0:
		return
	var origin := _target_aim_point(primary)
	var splash := amount * splash_ratio
	for node in get_tree().get_nodes_in_group("damageable"):
		if node == primary or not is_instance_valid(node):
			continue
		if int(node.get("team")) == team or node.get("alive") == false:
			continue
		if origin.distance_to(_target_aim_point(node)) <= splash_radius:
			node.apply_damage(splash, team)


func _target_aim_point(target: Node) -> Vector2:
	if target.has_method("get_selection_rect"):
		var r: Rect2 = target.get_selection_rect()
		return r.get_center()
	return target.global_position


func _find_nearest_enemy(max_dist: float) -> Node:
	var best: Node = null
	var best_d := max_dist
	for node in get_tree().get_nodes_in_group("damageable"):
		if not is_instance_valid(node):
			continue
		if int(node.get("team")) == team:
			continue
		if node.get("alive") == false:
			continue
		if team == GameConstants.Team.PLAYER and not _is_target_visible(node):
			continue
		var d := global_position.distance_to(_target_aim_point(node))
		if d < best_d:
			best_d = d
			best = node
	return best


func _is_target_visible(target: Node) -> bool:
	if _vision == null:
		_bind_systems()
	if _vision == null:
		return true
	return bool(_vision.is_world_visible(_target_aim_point(target)))


func _move_toward_target(delta: float) -> bool:
	if _target == null:
		if not _pull_next_waypoint():
			velocity = Vector2.ZERO
			return true
	var dest: Vector2 = _target
	var to := dest - global_position
	if to.length() < 8.0:
		_target = null
		if not _pull_next_waypoint():
			_manual_move = false
			velocity = Vector2.ZERO
			global_position = dest
			return true
		dest = _target
		to = dest - global_position
		if to.length() < 0.01:
			return false
	var before := global_position
	velocity = to.normalized() * move_speed
	move_and_slide()
	var moved := before.distance_to(global_position)
	if moved < 0.35:
		_stuck_time += delta
		if _stuck_time >= 1.15:
			_stuck_time = 0.0
			_recover_stuck()
	else:
		_stuck_time = 0.0
	return false


func _pull_next_waypoint() -> bool:
	_wp_index += 1
	if _wp_index < _waypoints.size():
		_target = _waypoints[_wp_index]
		return true
	if _has_goal and global_position.distance_to(_goal) > 14.0:
		_target = _goal
		_has_goal = false
		return true
	_has_goal = false
	_waypoints.clear()
	_wp_index = 0
	_target = null
	return false


func _recover_stuck() -> void:
	global_position += Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
	var dest := _goal if _has_goal else Vector2.ZERO
	if dest == Vector2.ZERO and not _waypoints.is_empty():
		dest = _waypoints[_waypoints.size() - 1]
	if dest != Vector2.ZERO:
		set_destination(dest)


func _draw() -> void:
	# Art pass v0.1: readable class silhouettes (placeholder, not final art)
	match unit_id:
		"u_infantry", "u_trooper_h", "ash_infantry", "ash_flame", "coil_infantry", "coil_guard":
			var half := Vector2(radius * 0.55, radius)
			draw_rect(Rect2(-half, half * 2.0), team_color, true)
			draw_circle(Vector2(0, -radius * 0.55), radius * 0.35, team_color.lightened(0.1))
			if unit_id == "ash_flame":
				draw_circle(Vector2(0, -radius * 0.2), 4.0, Color(1.0, 0.7, 0.2))
			elif unit_id == "coil_guard":
				draw_rect(Rect2(Vector2(-radius * 0.35, radius * 0.15), Vector2(radius * 0.7, 3)), Color(0.5, 0.9, 1.0, 0.7), true)
		"u_trike", "ash_trike", "coil_trike":
			var wedge := PackedVector2Array([
				Vector2(radius * 1.1, 0), Vector2(-radius * 0.7, -radius * 0.85), Vector2(-radius * 0.7, radius * 0.85)
			])
			draw_colored_polygon(wedge, team_color)
			draw_circle(Vector2(-radius * 0.35, -radius * 0.55), 2.2, team_color.darkened(0.25))
			draw_circle(Vector2(-radius * 0.35, radius * 0.55), 2.2, team_color.darkened(0.25))
		"u_siege", "u_msa":
			draw_rect(Rect2(Vector2(-radius, -radius * 0.7), Vector2(radius * 2.0, radius * 1.4)), team_color, true)
			draw_circle(Vector2(0, -radius * 0.2), radius * 0.45, team_color.lightened(0.2))
			draw_line(Vector2(0, -radius * 0.2), Vector2(radius * 1.15, -radius * 0.55), team_color.darkened(0.2), 2.5)
		"u_tank", "u_quad", "ash_tank", "ash_quad", "coil_tank", "coil_quad":
			draw_rect(Rect2(Vector2(-radius, -radius * 0.85), Vector2(radius * 2.0, radius * 1.7)), team_color, true)
			draw_rect(
				Rect2(Vector2(-radius * 0.55, -radius * 0.35), Vector2(radius * 1.1, radius * 0.7)),
				team_color.darkened(0.12),
				true
			)
		"coil_air":
			var pts := PackedVector2Array([
				Vector2(0, -radius), Vector2(radius, 0), Vector2(0, radius * 0.6), Vector2(-radius, 0)
			])
			draw_colored_polygon(pts, team_color)
			draw_line(Vector2(-radius * 1.2, 0), Vector2(radius * 1.2, 0), team_color.lightened(0.3), 2.0)
		_:
			draw_circle(Vector2.ZERO, radius, team_color)
	if flying:
		draw_arc(Vector2.ZERO, radius + 3.0, 0, TAU, 20, Color(0.6, 0.95, 1.0, 0.55), 1.2)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 24, Color(0, 0, 0, 0.55), 2.0)
	if selected:
		draw_arc(Vector2.ZERO, radius + 4.0, 0, TAU, 28, Color(1, 1, 0.3), 2.0)
	if _hold:
		draw_arc(Vector2.ZERO, radius + 7.0, 0, TAU, 20, Color(0.95, 0.55, 0.2), 1.5)
	draw_circle(Vector2(radius * 0.55, 0), 3.0, Color(1, 1, 1, 0.85))
	var ratio := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	var bar_w := radius * 2.0
	draw_rect(Rect2(Vector2(-radius, -radius - 7), Vector2(bar_w, 3)), Color(0, 0, 0, 0.55), true)
	draw_rect(Rect2(Vector2(-radius, -radius - 7), Vector2(bar_w * ratio, 3)), Color(0.2, 0.85, 0.3), true)
	var font := ThemeDB.fallback_font
	if font and short_label != "":
		var fs := 9
		var tw := font.get_string_size(short_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, Vector2(-tw.x * 0.5, radius + 11.0), short_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.9, 0.7))
	if _attack_target != null and is_instance_valid(_attack_target) and _attack_cd > 0.28:
		var aim := to_local(_target_aim_point(_attack_target))
		draw_line(Vector2.ZERO, aim, Color(1, 0.85, 0.2, 0.7), 1.5)
