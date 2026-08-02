extends SceneTree
## S3 smoke: credits → place Factory → queue Tank → unit spawns.
## Run: godot --headless --path . -s res://scripts/smoke_build.gd

const TIMEOUT_SEC := 30.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[smoke_build] starting")
	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("[smoke_build] load main failed: %s" % err)
		quit(1)
		return

	for i in 12:
		await physics_frame

	var root := current_scene
	if root == null:
		push_error("[smoke_build] no scene")
		quit(1)
		return

	var economy: Node = root.get_node_or_null("Economy")
	var bc: Node2D = root.get_node_or_null("BuildController")
	var units: Node2D = root.get_node_or_null("Units")
	var buildings: Node2D = root.get_node_or_null("Buildings")
	if economy == null or bc == null or units == null or buildings == null:
		push_error("[smoke_build] missing nodes")
		quit(1)
		return

	var units_before := units.get_child_count()
	var buildings_before := buildings.get_child_count()

	# Fund construction + tank without waiting on harvest
	economy.add_credits(2000)
	print("[smoke_build] credits=%d buildings=%d units=%d" % [
		economy.credits, buildings_before, units_before
	])

	# Place factory on free rock near base (avoid CY/power/refinery footprints)
	var factory: Node = bc.try_place_at("b_factory", Vector2i(12, 18), true)
	if factory == null:
		# fallback cells
		for cell in [Vector2i(14, 20), Vector2i(10, 20), Vector2i(16, 20), Vector2i(18, 14)]:
			factory = bc.try_place_at("b_factory", cell, true)
			if factory:
				break
	if factory == null:
		push_error("[smoke_build] failed to place factory")
		quit(1)
		return

	if buildings.get_child_count() <= buildings_before:
		push_error("[smoke_build] building count did not increase")
		quit(1)
		return

	if not factory.enqueue_unit("u_tank", true):
		push_error("[smoke_build] enqueue tank failed (credits=%d)" % economy.credits)
		quit(1)
		return
	if factory.get_queue_snapshot().is_empty():
		push_error("[smoke_build] queue empty after enqueue")
		quit(1)
		return
	factory.set_front_job_remaining(0.35)


	var elapsed := 0.0
	while elapsed < TIMEOUT_SEC:
		await physics_frame
		elapsed += 1.0 / 60.0
		if units.get_child_count() > units_before:
			print("[smoke_build] factory placed, tank spawned, units=%d credits=%d after ~%.1fs OK" % [
				units.get_child_count(), economy.credits, elapsed
			])
			quit(0)
			return

	push_error("[smoke_build] timeout waiting for produced unit")
	print("[smoke_build] queue=%s units=%d" % [factory.get_queue_snapshot(), units.get_child_count()])
	quit(1)
