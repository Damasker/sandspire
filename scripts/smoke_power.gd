extends SceneTree
## S5 smoke: production ticks with power; pauses after Windtrap destroyed.
## Run: godot --headless --path . -s res://scripts/smoke_power.gd


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[smoke_power] starting")
	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("[smoke_power] load failed")
		quit(1)
		return

	for i in 20:
		await physics_frame

	var root := current_scene
	var economy: Node = root.get_node("Economy")
	var power: Node = root.get_node("PowerGrid")
	var bc: Node2D = root.get_node("BuildController")

	power.recalculate()
	print("[smoke_power] baseline power %+d (%d/%d)" % [power.surplus, power.produced, power.consumed])
	if power.produced < 100 or power.surplus <= 0:
		push_error("[smoke_power] expected starting surplus from Windtrap")
		quit(1)
		return

	# Prereq: turret needs barracks — should fail before barracks
	if BuildingDatabase.meets_prereqs(self, "b_turret"):
		push_error("[smoke_power] turret prereq incorrectly satisfied")
		quit(1)
		return

	economy.add_credits(3000)
	var barracks: Node = null
	for cell in [Vector2i(14, 18), Vector2i(10, 18), Vector2i(16, 20)]:
		barracks = bc.try_place_at("b_barracks", cell, true)
		if barracks:
			break
	if barracks == null:
		push_error("[smoke_power] barracks place failed")
		quit(1)
		return

	if not BuildingDatabase.meets_prereqs(self, "b_turret"):
		push_error("[smoke_power] turret prereq still missing after barracks")
		quit(1)
		return

	var factory: Node = null
	for cell in [Vector2i(12, 20), Vector2i(10, 20), Vector2i(14, 20)]:
		factory = bc.try_place_at("b_factory", cell, true)
		if factory:
			break
	if factory == null:
		push_error("[smoke_power] factory place failed")
		quit(1)
		return

	power.recalculate()
	print("[smoke_power] after consumers surplus=%d (%d/%d)" % [
		power.surplus, power.produced, power.consumed
	])

	if not factory.enqueue_unit("u_tank", true):
		push_error("[smoke_power] enqueue failed")
		quit(1)
		return
	factory.set_front_job_remaining(5.0)

	# Tick with power — remaining must drop
	for i in 45:
		await physics_frame
	var rem_powered: float = float(factory.get_queue_snapshot()[0]["remaining"])
	print("[smoke_power] remaining with power=%.2f" % rem_powered)
	if rem_powered >= 4.85:
		push_error("[smoke_power] production did not advance under power")
		quit(1)
		return

	# Destroy all windtraps → low power → pause
	for b in get_nodes_in_group("power_plants"):
		if int(b.get("team")) == GameConstants.Team.PLAYER:
			b.apply_damage(9999.0, GameConstants.Team.ENEMY)

	for i in 10:
		await physics_frame
	power.recalculate()
	if not power.is_low_power():
		push_error("[smoke_power] expected low power after killing Windtrap (surplus=%d)" % power.surplus)
		quit(1)
		return

	var rem_before_pause: float = float(factory.get_queue_snapshot()[0]["remaining"])
	for i in 60:
		await physics_frame
	var rem_after_pause: float = float(factory.get_queue_snapshot()[0]["remaining"])
	print("[smoke_power] low-power remaining %.2f → %.2f (surplus=%d)" % [
		rem_before_pause, rem_after_pause, power.surplus
	])

	if rem_after_pause < rem_before_pause - 0.05:
		push_error("[smoke_power] production advanced while low power")
		quit(1)
		return
	if not factory.is_production_paused():
		push_error("[smoke_power] factory not reporting paused")
		quit(1)
		return

	print("[smoke_power] OK — production paused under power deficit")
	quit(0)
