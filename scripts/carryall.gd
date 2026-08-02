extends Unit
## Airlift assist: pick up distant SEEKing harvesters, drop on spice (post-MVP).

enum CarryState { IDLE, TO_PICKUP, TO_DROP }

var carry_state: CarryState = CarryState.IDLE
var passenger: Node = null
var drop_pos: Vector2 = Vector2.ZERO
var auto_assist: bool = true
var pickup_range: float = 48.0
var assist_distance: float = 380.0
var jobs_done: int = 0


func _ready() -> void:
	if not str(unit_id).contains("carryall"):
		unit_id = "u_carryall"
	auto_acquire = false
	super._ready()
	auto_acquire = false
	dps = 0.0
	flying = true
	z_index = 26
	add_to_group("carryalls")
	add_to_group("air_units")
	_def = UnitDatabase.get_unit(unit_id)
	if _def.has("pickup_range"):
		pickup_range = float(_def["pickup_range"])
	if _def.has("assist_distance"):
		assist_distance = float(_def["assist_distance"])
	if _def.has("auto_assist"):
		auto_assist = bool(_def["auto_assist"])
	if _def.has("speed"):
		move_speed = float(_def["speed"])
	if _def.has("radius"):
		radius = float(_def["radius"])
		var shape := $CollisionShape2D.shape as CircleShape2D
		if shape:
			shape.radius = radius


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if _manual_move:
		if _move_toward_target(delta):
			_manual_move = false
		_sync_passenger()
		queue_redraw()
		return

	match carry_state:
		CarryState.IDLE:
			velocity = Vector2.ZERO
			if auto_assist:
				_try_find_job()
		CarryState.TO_PICKUP:
			_tick_to_pickup(delta)
		CarryState.TO_DROP:
			_tick_to_drop(delta)
	_sync_passenger()
	queue_redraw()


func command_move(world_pos: Vector2) -> void:
	if passenger != null and bool(passenger.get("carried")):
		drop_pos = world_pos
		carry_state = CarryState.TO_DROP
		set_destination(drop_pos)
		_manual_move = false
		return
	super.command_move(world_pos)


func _try_find_job() -> void:
	var best: Node = null
	var best_score := -1.0
	for h in get_tree().get_nodes_in_group("harvesters"):
		if not is_instance_valid(h) or h.get("alive") == false:
			continue
		if int(h.get("team")) != team:
			continue
		if bool(h.get("carried")):
			continue
		if h.has_method("wants_carryall_assist") and not h.wants_carryall_assist(assist_distance):
			continue
		var spice_pos: Vector2 = (
			h.get_assist_drop_position()
			if h.has_method("get_assist_drop_position")
			else h.global_position
		)
		var ground_dist: float = h.global_position.distance_to(spice_pos)
		if ground_dist < assist_distance:
			continue
		var score := ground_dist - global_position.distance_to(h.global_position) * 0.25
		if score > best_score:
			best_score = score
			best = h
			drop_pos = spice_pos
	if best == null:
		return
	passenger = best
	carry_state = CarryState.TO_PICKUP
	set_destination(best.global_position)


func _tick_to_pickup(delta: float) -> void:
	if passenger == null or not is_instance_valid(passenger) or passenger.get("alive") == false:
		_abort_job()
		return
	if bool(passenger.get("carried")):
		_abort_job()
		return
	set_destination(passenger.global_position)
	_move_toward_target(delta)
	if global_position.distance_to(passenger.global_position) <= pickup_range:
		_lift()


func _lift() -> void:
	if passenger == null or not is_instance_valid(passenger):
		_abort_job()
		return
	if not passenger.has_method("begin_carry"):
		_abort_job()
		return
	passenger.begin_carry(self)
	carry_state = CarryState.TO_DROP
	if drop_pos == Vector2.ZERO:
		drop_pos = passenger.global_position + Vector2(200, 0)
	set_destination(drop_pos)


func _tick_to_drop(delta: float) -> void:
	if passenger == null or not is_instance_valid(passenger):
		_abort_job()
		return
	_move_toward_target(delta)
	if global_position.distance_to(drop_pos) <= 28.0:
		_drop()


func _drop() -> void:
	if passenger and is_instance_valid(passenger) and passenger.has_method("end_carry"):
		passenger.end_carry(drop_pos)
	passenger = null
	drop_pos = Vector2.ZERO
	carry_state = CarryState.IDLE
	jobs_done += 1
	_has_goal = false
	_waypoints.clear()
	velocity = Vector2.ZERO


func _abort_job() -> void:
	if passenger and is_instance_valid(passenger) and bool(passenger.get("carried")):
		if passenger.has_method("end_carry"):
			passenger.end_carry(passenger.global_position)
	passenger = null
	drop_pos = Vector2.ZERO
	carry_state = CarryState.IDLE


func _sync_passenger() -> void:
	if passenger == null or not is_instance_valid(passenger):
		return
	if bool(passenger.get("carried")):
		passenger.global_position = global_position + Vector2(0, 10)


func _draw() -> void:
	var body := Rect2(Vector2(-radius * 1.3, -radius * 0.45), Vector2(radius * 2.6, radius * 0.9))
	draw_rect(body, team_color, true)
	draw_rect(
		Rect2(Vector2(-radius * 0.3, -radius), Vector2(radius * 0.6, radius * 0.55)),
		team_color.lightened(0.15),
		true
	)
	draw_line(Vector2(-radius * 1.4, 0), Vector2(radius * 1.4, 0), team_color.darkened(0.2), 2.0)
	if passenger != null:
		draw_arc(Vector2.ZERO, radius + 6.0, 0, TAU, 22, Color(0.95, 0.85, 0.3, 0.7), 1.5)
	draw_arc(Vector2.ZERO, radius + 3.0, 0, TAU, 20, Color(0.6, 0.95, 1.0, 0.55), 1.2)
	if selected:
		draw_arc(Vector2.ZERO, radius + 8.0, 0, TAU, 28, Color(1, 1, 0.3), 2.0)
	var ratio := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	draw_rect(Rect2(Vector2(-radius, -radius - 8), Vector2(radius * 2.0, 3)), Color(0, 0, 0, 0.55), true)
	draw_rect(Rect2(Vector2(-radius, -radius - 8), Vector2(radius * 2.0 * ratio, 3)), Color(0.2, 0.85, 0.3), true)
	var font := ThemeDB.fallback_font
	if font and short_label != "":
		var fs := 9
		var tw := font.get_string_size(short_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(
			font,
			Vector2(-tw.x * 0.5, radius + 12.0),
			short_label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			fs,
			Color(0.95, 0.9, 0.7)
		)
