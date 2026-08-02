extends SceneTree
## M1 smoke: harvest credits → factory → tank → destroy enemy camp.
## Run: godot --headless --path . -s res://scripts/smoke_m1.gd

const HARVEST_TIMEOUT := 40.0
const COMBAT_TIMEOUT := 60.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[smoke_m1] starting M1 vertical slice")
	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("[smoke_m1] load failed: %s" % err)
		quit(1)
		return

	for i in 15:
		await physics_frame

	var root := current_scene
	var economy: Node = root.get_node("Economy")
	var mission: Node = root.get_node("Mission")
	var bc: Node2D = root.get_node("BuildController")
	var units: Node2D = root.get_node("Units")

	# Speed harvester
	for h in get_nodes_in_group("harvesters"):
		h.cargo_capacity = 30
		h.harvest_rate = 140.0
		h.unload_rate = 180.0
		h.move_speed = 260.0

	# 1) Prove harvest loop earns credits
	var elapsed := 0.0
	while economy.credits <= 0 and elapsed < HARVEST_TIMEOUT:
		await physics_frame
		elapsed += 1.0 / 60.0
	if economy.credits <= 0:
		push_error("[smoke_m1] harvest failed — no credits")
		quit(1)
		return
	print("[smoke_m1] harvest OK credits=%d (%.1fs)" % [economy.credits, elapsed])

	# 2) Fund + place factory + produce tanks (accelerated)
	economy.add_credits(2000)
	var factory: Node = null
	for cell in [Vector2i(12, 18), Vector2i(14, 20), Vector2i(10, 20), Vector2i(16, 20)]:
		factory = bc.try_place_at("b_factory", cell, true)
		if factory:
			break
	if factory == null:
		push_error("[smoke_m1] factory place failed")
		quit(1)
		return

	var units_before := units.get_child_count()
	if not factory.enqueue_unit("u_tank", true):
		push_error("[smoke_m1] enqueue tank failed")
		quit(1)
		return
	factory.set_front_job_remaining(0.2)
	if not factory.enqueue_unit("u_tank", true):
		push_error("[smoke_m1] enqueue 2nd tank failed")
		quit(1)
		return
	# second job will start after first finishes; shorten when it becomes front
	elapsed = 0.0
	var tanks: Array = []
	while elapsed < 10.0 and tanks.size() < 2:
		await physics_frame
		elapsed += 1.0 / 60.0
		var q: Array = factory.get_queue_snapshot()
		if not q.is_empty() and float(q[0].get("remaining", 99)) > 0.25:
			factory.set_front_job_remaining(0.15)
		tanks.clear()
		for u in units.get_children():
			if str(u.get("unit_id")) == "u_tank" and int(u.get("team")) == GameConstants.Team.PLAYER:
				tanks.append(u)

	if tanks.is_empty():
		push_error("[smoke_m1] no player tanks produced")
		quit(1)
		return
	print("[smoke_m1] produced tanks=%d (units %d→%d)" % [
		tanks.size(), units_before, units.get_child_count()
	])

	# 3) Soften camp + boost tanks, attack
	var camp: Node = null
	for b in get_nodes_in_group("enemy_camp"):
		camp = b
		break
	if camp == null:
		push_error("[smoke_m1] enemy camp missing")
		quit(1)
		return
	camp.hp = 160.0
	camp.max_hp = 160.0

	for t in tanks:
		t.dps = 80.0
		t.attack_range = 180.0
		t.move_speed = 200.0
		t.command_attack(camp)

	# Also send starting combat units
	for u in units.get_children():
		if int(u.get("team")) != GameConstants.Team.PLAYER:
			continue
		if str(u.get("unit_id")) in ["u_trike", "u_infantry", "u_quad", "u_tank"]:
			if u.has_method("command_attack"):
				u.command_attack(camp)

	elapsed = 0.0
	while elapsed < COMBAT_TIMEOUT:
		await physics_frame
		elapsed += 1.0 / 60.0
		if mission.is_camp_destroyed() or mission.completed:
			print("[smoke_m1] CAMP DESTROYED after ~%.1fs — M1 OK" % elapsed)
			quit(0)
			return

	push_error("[smoke_m1] timeout — camp hp=%s alive=%s" % [
		camp.hp if is_instance_valid(camp) else "gone",
		mission.camp_alive,
	])
	quit(1)
