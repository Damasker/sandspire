extends SceneTree
## S10 smoke: Ashveil faction data loads; sandworm swallows a harvester on sand.
## Run: godot --headless --path . -s res://scripts/smoke_worm.gd


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[smoke_worm] starting")

	var ash := FactionDatabase.get_faction("ashveil")
	if str(ash.get("id", "")) != "ashveil":
		push_error("[smoke_worm] ashveil faction missing")
		quit(1)
		return
	for uid in ["ash_infantry", "ash_flame", "ash_trike", "ash_quad", "ash_tank", "ash_harvester"]:
		var u := UnitDatabase.get_unit(uid)
		if str(u.get("id", "")) != uid:
			push_error("[smoke_worm] missing ash unit %s" % uid)
			quit(1)
			return
		if str(u.get("faction", "")) != "ashveil":
			push_error("[smoke_worm] %s not tagged ashveil" % uid)
			quit(1)
			return
	var flame := UnitDatabase.get_unit("ash_flame")
	if float(flame.get("splash_radius", 0)) <= 0.0:
		push_error("[smoke_worm] flame trooper needs splash_radius")
		quit(1)
		return
	print("[smoke_worm] Ashveil roster OK")

	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("[smoke_worm] main load failed")
		quit(1)
		return

	for i in 20:
		await physics_frame

	var root := current_scene
	var worm: Node2D = root.get_node_or_null("Sandworm")
	var world: Node2D = root.get_node("WorldMap")
	var ai: Node = root.get_node_or_null("AiController")
	if worm == null:
		push_error("[smoke_worm] Sandworm missing")
		quit(1)
		return
	if ai:
		ai.enabled = false
	worm.enabled = true
	worm.noise_threshold = 5.0

	# Place harvester on open sand (not rock)
	var harv: Node = null
	for h in get_nodes_in_group("harvesters"):
		harv = h
		break
	if harv == null:
		push_error("[smoke_worm] no harvester")
		quit(1)
		return

	var sand_pos: Vector2 = world.cell_to_world_center(Vector2i(28, 22))
	if world.is_worm_safe(sand_pos):
		sand_pos = world.cell_to_world_center(Vector2i(26, 26))
	harv.global_position = sand_pos
	if world.is_worm_safe(harv.global_position):
		push_error("[smoke_worm] test pos still worm-safe (rock)")
		quit(1)
		return

	var swallowed := false
	worm.unit_swallowed.connect(func(_u): swallowed = true)
	worm.force_emerge_at(sand_pos + Vector2(90, 40))
	# Keep attracting
	for i in 400:
		await physics_frame
		if worm.has_method("report_harvest_noise"):
			worm.report_harvest_noise(harv.global_position if is_instance_valid(harv) else sand_pos, 20.0)
		if swallowed or not is_instance_valid(harv):
			print("[smoke_worm] OK — worm swallowed harvester on sand (swallows=%d)" % int(worm.swallows))
			quit(0)
			return

	push_error("[smoke_worm] timeout — worm state=%s pos=%s harv=%s" % [
		worm.state, worm.global_position, harv.global_position if is_instance_valid(harv) else "gone"
	])
	quit(1)
