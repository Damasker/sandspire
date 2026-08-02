extends SceneTree
## S7 smoke: A* navigates around a blocked wall to a destination.
## Run: godot --headless --path . -s res://scripts/smoke_path.gd


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[smoke_path] starting")
	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("[smoke_path] load failed")
		quit(1)
		return

	for i in 30:
		await physics_frame

	var root := current_scene
	var pf: Node = root.get_node_or_null("Pathfinder")
	if pf == null:
		push_error("[smoke_path] missing Pathfinder")
		quit(1)
		return

	# Vertical wall of blocked cells between start and goal
	pf.clear_temp_blocked()
	pf.set_temp_blocked_rect(Vector2i(22, 8), Vector2i(2, 14), true)

	var start_cell := Vector2i(16, 14)
	var goal_cell := Vector2i(30, 14)
	var world_map: Node2D = root.get_node("WorldMap")
	var start_pos: Vector2 = world_map.cell_to_world_center(start_cell)
	var goal_pos: Vector2 = world_map.cell_to_world_center(goal_cell)

	var path: PackedVector2Array = pf.find_path(start_pos, goal_pos)
	if path.size() < 4:
		push_error("[smoke_path] path too short (%d) — expected detour" % path.size())
		quit(1)
		return

	# Path must not enter the temp wall
	for p in path:
		var c: Vector2i = world_map.world_to_cell(p)
		if not pf.is_walkable(c):
			push_error("[smoke_path] path entered blocked cell %s" % c)
			quit(1)
			return
	print("[smoke_path] A* waypoints=%d OK" % path.size())

	# Live unit: walk around the wall
	var unit: Node = null
	for u in get_nodes_in_group("team_player"):
		if u.is_in_group("units") and str(u.get("unit_id")) == "u_trike":
			unit = u
			break
	if unit == null:
		push_error("[smoke_path] no trike")
		quit(1)
		return

	unit.global_position = start_pos
	unit.command_move(goal_pos)

	var reached := false
	var deep_block_frames := 0
	for i in 1200:
		await physics_frame
		if unit == null or not is_instance_valid(unit):
			break
		# Allow grazing corners; fail only if sitting inside a blocked cell
		var cell_now: Vector2i = world_map.world_to_cell(unit.global_position)
		var center: Vector2 = world_map.cell_to_world_center(cell_now)
		if not pf.is_walkable(cell_now) and unit.global_position.distance_to(center) < 10.0:
			deep_block_frames += 1
			if deep_block_frames > 20:
				push_error("[smoke_path] unit stuck inside blocked cell %s" % cell_now)
				quit(1)
				return
		else:
			deep_block_frames = 0
		if unit.global_position.distance_to(goal_pos) < 28.0:
			reached = true
			break

	if not reached:
		push_error(
			"[smoke_path] unit failed to reach goal (pos=%s dist=%.1f)"
			% [unit.global_position, unit.global_position.distance_to(goal_pos)]
		)
		quit(1)
		return

	# Orders smoke: stop / hold / attack-move exist
	if not unit.has_method("command_attack_move") or not unit.has_method("command_hold"):
		push_error("[smoke_path] missing order APIs")
		quit(1)
		return
	unit.command_hold()
	if not bool(unit.get("_hold")):
		push_error("[smoke_path] hold did not stick")
		quit(1)
		return
	unit.command_stop()
	unit.command_attack_move(start_pos)

	print("[smoke_path] OK — navigated around obstacle + orders")
	quit(0)
