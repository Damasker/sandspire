extends SceneTree
## S11 smoke: Coilward data loads; air unit flies over buildings to a target.
## Run: godot --headless --path . -s res://scripts/smoke_coil.gd


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[smoke_coil] starting")
	var coil := FactionDatabase.get_faction("coilward")
	if str(coil.get("id", "")) != "coilward":
		push_error("[smoke_coil] coilward faction missing")
		quit(1)
		return
	for uid in [
		"coil_infantry", "coil_guard", "coil_harvester",
		"coil_trike", "coil_quad", "coil_tank", "coil_air",
	]:
		var u := UnitDatabase.get_unit(uid)
		if str(u.get("id", "")) != uid:
			push_error("[smoke_coil] missing unit %s" % uid)
			quit(1)
			return
		if str(u.get("faction", "")) != "coilward":
			push_error("[smoke_coil] %s not tagged coilward" % uid)
			quit(1)
			return
	if not bool(UnitDatabase.get_unit("coil_air").get("flying", false)):
		push_error("[smoke_coil] coil_air must be flying")
		quit(1)
		return
	var mods: Dictionary = FactionDatabase.building_mods("coilward", "b_turret")
	if float(mods.get("dps", 0)) < 25.0:
		push_error("[smoke_coil] coilward turret mod too weak")
		quit(1)
		return
	var radar_prod: Array = FactionDatabase.produces_for("coilward", "b_radar")
	if "coil_air" not in radar_prod:
		push_error("[smoke_coil] outpost must produce coil_air")
		quit(1)
		return
	print("[smoke_coil] Coilward roster + turret/air specials OK")

	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("[smoke_coil] main load failed")
		quit(1)
		return
	for i in 20:
		await physics_frame

	var root := current_scene
	var ai: Node = root.get_node_or_null("AiController")
	if ai:
		ai.enabled = false
	var worm: Node = root.get_node_or_null("Sandworm")
	if worm:
		worm.enabled = false

	var units_root: Node2D = root.get_node("Units")
	var pf: Node = root.get_node("Pathfinder")
	# Block a wall of cells between start and goal — ground path must detour
	pf.clear_temp_blocked()
	pf.set_temp_blocked_rect(Vector2i(18, 10), Vector2i(2, 12), true)

	var world: Node2D = root.get_node("WorldMap")
	var start: Vector2 = world.cell_to_world_center(Vector2i(14, 14))
	var goal: Vector2 = world.cell_to_world_center(Vector2i(28, 14))

	var ground_path: PackedVector2Array = pf.find_path(start, goal)
	if ground_path.size() < 4:
		push_error("[smoke_coil] expected ground detour path, got %d" % ground_path.size())
		quit(1)
		return

	var scene := preload("res://scenes/unit.tscn")
	var air: CharacterBody2D = scene.instantiate()
	air.unit_id = "coil_air"
	air.team = GameConstants.Team.PLAYER
	air.global_position = start
	units_root.add_child(air)
	await physics_frame
	if not bool(air.flying):
		push_error("[smoke_coil] air.flying false after spawn")
		quit(1)
		return

	air.command_move(goal)
	# Flying should take a direct waypoint (ignore blocks)
	if air._waypoints.size() != 1:
		push_error("[smoke_coil] air should fly direct (waypoints=%d)" % air._waypoints.size())
		quit(1)
		return

	var reached := false
	var crossed_block := false
	for i in 600:
		await physics_frame
		if not is_instance_valid(air):
			break
		var cell: Vector2i = world.world_to_cell(air.global_position)
		if cell.x >= 18 and cell.x <= 19 and cell.y >= 10 and cell.y <= 21:
			crossed_block = true
		if air.global_position.distance_to(goal) < 28.0:
			reached = true
			break

	if not reached:
		push_error("[smoke_coil] air failed to reach goal")
		quit(1)
		return
	if not crossed_block:
		push_error("[smoke_coil] air never crossed blocked cells (did not fly over)")
		quit(1)
		return

	print("[smoke_coil] OK — air flew over blocks (ground waypoints=%d)" % ground_path.size())
	quit(0)
