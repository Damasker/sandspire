extends Unit
## Spice harvester FSM: seek → harvest → return → unload → credits.

enum State { IDLE, SEEK, HARVEST, RETURN, UNLOAD }

@export var cargo_capacity: int = 100
@export var harvest_rate: float = 40.0  # spice per second
@export var unload_rate: float = 80.0   # spice per second → credits

var state: State = State.IDLE
var cargo: int = 0
var auto_harvest: bool = true

var _world_map: Node2D
var _economy: Node
var _sandworm: Node2D
var _harvest_cell: Vector2i = Vector2i(-1, -1)
var _harvest_accum: float = 0.0
var _unload_accum: float = 0.0
var _refinery: Node2D


func _ready() -> void:
	if not str(unit_id).contains("harvester"):
		unit_id = "u_harvester"
	if radius < 12.0:
		radius = 14.0
	auto_acquire = false
	super._ready()
	auto_acquire = false
	dps = 0.0
	add_to_group("harvesters")
	_def = UnitDatabase.get_unit(unit_id)
	if _def.has("cargo_capacity"):
		cargo_capacity = int(_def["cargo_capacity"])
	if _def.has("harvest_rate"):
		harvest_rate = float(_def["harvest_rate"])
	if _def.has("unload_rate"):
		unload_rate = float(_def["unload_rate"])
	if _def.has("speed"):
		move_speed = float(_def["speed"])
	if _def.has("radius"):
		radius = float(_def["radius"])
		var shape := $CollisionShape2D.shape as CircleShape2D
		if shape:
			shape.radius = radius
	call_deferred("_bind_world")


func _bind_world() -> void:
	var main := get_tree().current_scene
	if main == null:
		main = get_parent().get_parent()
	_world_map = main.get_node_or_null("WorldMap")
	_sandworm = main.get_node_or_null("Sandworm")
	if team == GameConstants.Team.ENEMY:
		_economy = main.get_node_or_null("EnemyEconomy")
	else:
		_economy = main.get_node_or_null("Economy")
	if auto_harvest and state == State.IDLE:
		_enter(State.SEEK)


func command_move(world_pos: Vector2) -> void:
	## Manual move pauses auto FSM until arrival, then resumes.
	super.command_move(world_pos)
	state = State.IDLE


func _physics_process(delta: float) -> void:
	if _manual_move:
		if _move_toward_target(delta):
			if auto_harvest:
				_enter(State.SEEK if cargo < cargo_capacity else State.RETURN)
		queue_redraw()
		return

	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			if auto_harvest:
				_enter(State.SEEK if cargo < cargo_capacity else State.RETURN)
		State.SEEK:
			_tick_seek(delta)
		State.HARVEST:
			_tick_harvest(delta)
		State.RETURN:
			_tick_return(delta)
		State.UNLOAD:
			_tick_unload(delta)
	queue_redraw()


func _enter(next: State) -> void:
	state = next
	_harvest_accum = 0.0
	_unload_accum = 0.0
	match state:
		State.SEEK:
			_pick_spice_target()
		State.RETURN:
			_pick_refinery()
		State.IDLE, State.HARVEST, State.UNLOAD:
			pass


func _pick_spice_target() -> void:
	if _world_map == null or not _world_map.has_method("find_nearest_spice_cell"):
		_enter(State.IDLE)
		auto_harvest = false
		return
	var cell: Vector2i = _world_map.find_nearest_spice_cell(global_position)
	if cell.x < 0:
		_enter(State.IDLE)
		return
	_harvest_cell = cell
	set_destination(_world_map.cell_to_world_center(cell))


func _pick_refinery() -> void:
	_refinery = _find_nearest_refinery()
	if _refinery == null:
		_enter(State.IDLE)
		return
	set_destination(_refinery.get_unload_position())


func _find_nearest_refinery() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("refineries"):
		if not node is Node2D:
			continue
		if int(node.get("team")) != team:
			continue
		var d: float = global_position.distance_squared_to(node.get_unload_position())
		if d < best_d:
			best_d = d
			best = node
	return best


func _tick_seek(delta: float) -> void:
	if _harvest_cell.x >= 0 and _world_map.get_spice_at(_harvest_cell) <= 0:
		_pick_spice_target()
		return
	if _move_toward_target(delta):
		if _world_map.get_spice_at(_harvest_cell) > 0:
			_enter(State.HARVEST)
		else:
			_pick_spice_target()


func _tick_harvest(delta: float) -> void:
	velocity = Vector2.ZERO
	if cargo >= cargo_capacity:
		_enter(State.RETURN)
		return
	if _world_map.get_spice_at(_harvest_cell) <= 0:
		if cargo > 0:
			_enter(State.RETURN)
		else:
			_enter(State.SEEK)
		return
	_harvest_accum += harvest_rate * delta
	var take := int(_harvest_accum)
	if take <= 0:
		return
	_harvest_accum -= float(take)
	var room := cargo_capacity - cargo
	take = mini(take, room)
	var got: int = _world_map.harvest_spice(_harvest_cell, take)
	cargo += got
	if got > 0:
		_report_worm_noise(float(got) * 0.35)
	if cargo >= cargo_capacity:
		_enter(State.RETURN)


func _report_worm_noise(intensity: float) -> void:
	if _sandworm == null:
		var main := get_tree().current_scene
		if main:
			_sandworm = main.get_node_or_null("Sandworm")
	if _sandworm and _sandworm.has_method("report_harvest_noise"):
		_sandworm.report_harvest_noise(global_position, intensity)


func _tick_return(delta: float) -> void:
	if _refinery == null or not is_instance_valid(_refinery):
		_pick_refinery()
		if _refinery == null:
			return
	if _target == null and _waypoints.is_empty():
		set_destination(_refinery.get_unload_position())
	if _move_toward_target(delta):
		_enter(State.UNLOAD)


func _tick_unload(delta: float) -> void:
	velocity = Vector2.ZERO
	if cargo <= 0:
		_enter(State.SEEK)
		return
	_unload_accum += unload_rate * delta
	var give := int(_unload_accum)
	if give <= 0:
		return
	_unload_accum -= float(give)
	give = mini(give, cargo)
	cargo -= give
	if _economy and _economy.has_method("add_credits"):
		_economy.add_credits(give)
	if cargo <= 0:
		_enter(State.SEEK)


func _draw() -> void:
	super._draw()
	# Cargo bar
	var ratio := float(cargo) / float(maxi(cargo_capacity, 1))
	var bar := Rect2(Vector2(-radius, -radius - 8), Vector2(radius * 2.0 * ratio, 3))
	draw_rect(Rect2(Vector2(-radius, -radius - 8), Vector2(radius * 2.0, 3)), Color(0, 0, 0, 0.5), true)
	draw_rect(bar, Color(0.85, 0.65, 0.15), true)
