extends Node2D
## Simple sandworm FSM: dormant → approach → feast → leave.
## Aggro from harvester noise on sand/spice/bloom. Rock is safe.

signal emerged(at: Vector2)
signal unit_swallowed(unit: Node)
signal left_map

enum State { DORMANT, APPROACH, FEAST, LEAVING }

@export var enabled: bool = true
@export var noise_threshold: float = 40.0
@export var move_speed: float = 160.0
@export var swallow_radius: float = 28.0

var state: State = State.DORMANT
var noise: float = 0.0
var swallows: int = 0
var _world_map: Node2D
var _target: Node = null
var _noise_pos: Vector2 = Vector2.ZERO
var _feast_timer: float = 0.0
var _leave_timer: float = 0.0
var _bob: float = 0.0
var _visible_body: bool = false


func _ready() -> void:
	z_index = 30
	add_to_group("sandworm")
	call_deferred("_bind")
	visible = false


func _bind() -> void:
	var main := get_tree().current_scene
	if main:
		_world_map = main.get_node_or_null("WorldMap")


func report_harvest_noise(world_pos: Vector2, intensity: float = 8.0) -> void:
	if not enabled or intensity <= 0.0:
		return
	if _world_map == null:
		_bind()
	if _world_map and _world_map.has_method("is_worm_safe") and _world_map.is_worm_safe(world_pos):
		return
	noise += intensity
	_noise_pos = world_pos
	if state == State.DORMANT and noise >= noise_threshold:
		_emerge(world_pos)


func force_emerge_at(world_pos: Vector2) -> void:
	noise = noise_threshold
	_emerge(world_pos)


func _emerge(near: Vector2) -> void:
	state = State.APPROACH
	_visible_body = true
	visible = true
	global_position = near + Vector2(120, 80)
	if _world_map and _world_map.has_method("is_worm_safe") and _world_map.is_worm_safe(global_position):
		global_position = near + Vector2(0, 100)
	swallows = 0
	_pick_target()
	emerged.emit(global_position)
	queue_redraw()


func _pick_target() -> void:
	_target = null
	var best_d := INF
	for h in get_tree().get_nodes_in_group("harvesters"):
		if not is_instance_valid(h) or h.get("alive") == false:
			continue
		if bool(h.get("flying")):
			continue
		if _world_map and _world_map.is_worm_safe(h.global_position):
			continue
		var d: float = global_position.distance_squared_to(h.global_position)
		if d < best_d:
			best_d = d
			_target = h
	if _target == null:
		# Any ground unit on sand near noise
		for u in get_tree().get_nodes_in_group("units"):
			if not is_instance_valid(u) or u.get("alive") == false:
				continue
			if bool(u.get("flying")) or u.is_in_group("air_units"):
				continue
			if _world_map and _world_map.is_worm_safe(u.global_position):
				continue
			var d2: float = global_position.distance_squared_to(u.global_position)
			if d2 < best_d:
				best_d = d2
				_target = u


func _process(delta: float) -> void:
	if not enabled:
		return
	_bob += delta * 4.0
	match state:
		State.DORMANT:
			noise = maxf(0.0, noise - 6.0 * delta)
		State.APPROACH:
			_tick_approach(delta)
		State.FEAST:
			_feast_timer -= delta
			_try_swallow_nearby()
			if _feast_timer <= 0.0 or swallows >= 2:
				_begin_leave()
		State.LEAVING:
			_leave_timer -= delta
			global_position.y += 40.0 * delta
			modulate.a = clampf(_leave_timer / 1.2, 0.0, 1.0)
			if _leave_timer <= 0.0:
				_go_dormant()
	queue_redraw()


func _tick_approach(delta: float) -> void:
	if _target == null or not is_instance_valid(_target) or _target.get("alive") == false:
		_pick_target()
		if _target == null:
			# Hunt noise point then leave if nothing
			var dest := _noise_pos
			global_position = global_position.move_toward(dest, move_speed * delta)
			if global_position.distance_to(dest) < 20.0:
				_begin_leave()
			return
	if _world_map and _world_map.is_worm_safe(_target.global_position):
		# Prey reached rock — break off
		_begin_leave()
		return
	var aim: Vector2 = _target.global_position
	global_position = global_position.move_toward(aim, move_speed * delta)
	if global_position.distance_to(aim) <= swallow_radius:
		_swallow(_target)


func _try_swallow_nearby() -> void:
	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u) or u.get("alive") == false:
			continue
		if _world_map and _world_map.is_worm_safe(u.global_position):
			continue
		if global_position.distance_to(u.global_position) <= swallow_radius * 1.15:
			_swallow(u)
			return


func _swallow(unit: Node) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if _world_map and _world_map.is_worm_safe(unit.global_position):
		return
	swallows += 1
	unit_swallowed.emit(unit)
	if unit.has_method("apply_damage"):
		unit.apply_damage(9999.0, -1)
	else:
		unit.queue_free()
	_target = null
	state = State.FEAST
	_feast_timer = 1.4
	noise = 0.0


func _begin_leave() -> void:
	state = State.LEAVING
	_leave_timer = 1.2
	_target = null


func _go_dormant() -> void:
	state = State.DORMANT
	_visible_body = false
	visible = false
	modulate.a = 1.0
	noise = 0.0
	left_map.emit()


func _draw() -> void:
	if not _visible_body or state == State.DORMANT:
		return
	var pulse := 1.0 + 0.08 * sin(_bob)
	var r := 34.0 * pulse
	draw_circle(Vector2.ZERO, r, Color(0.35, 0.22, 0.12, 0.92))
	draw_circle(Vector2(0, -6), r * 0.55, Color(0.55, 0.3, 0.15, 0.9))
	draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(0.15, 0.08, 0.05), 3.0)
	# Maw
	draw_circle(Vector2(0, 4), 10.0, Color(0.1, 0.05, 0.05))
