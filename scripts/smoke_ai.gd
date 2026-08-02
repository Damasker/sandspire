extends SceneTree
## S8 smoke: skirmish AI builds/produces and launches an attack wave.
## Run: godot --headless --path . -s res://scripts/smoke_ai.gd


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[smoke_ai] starting")
	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("[smoke_ai] load failed")
		quit(1)
		return

	for i in 25:
		await physics_frame

	var root := current_scene
	var ai: Node = root.get_node_or_null("AiController")
	var enemy_eco: Node = root.get_node_or_null("EnemyEconomy")
	if ai == null or enemy_eco == null:
		push_error("[smoke_ai] missing AiController/EnemyEconomy")
		quit(1)
		return

	ai.enabled = true
	ai.set_profile_override("think_interval", 0.05)
	ai.set_profile_override("wave_min_army", 2)
	ai.set_profile_override("wave_cooldown", 0.5)
	ai._think_cd = 0.0
	ai._wave_cd = 0.0
	enemy_eco.add_credits(3000)

	var player_cy: Node = null
	for b in get_nodes_in_group("conyards"):
		if int(b.get("team")) == GameConstants.Team.PLAYER:
			player_cy = b
			break
	if player_cy == null:
		push_error("[smoke_ai] no player CY")
		quit(1)
		return

	# Soft target so a short wave can register damage
	player_cy.hp = 180.0
	player_cy.max_hp = 180.0
	var hp_at_start: float = float(player_cy.hp)

	var elapsed := 0.0
	var saw_producer := false
	var saw_queue := false
	while elapsed < 50.0:
		await physics_frame
		elapsed += 1.0 / 60.0
		ai.force_think()

		if _enemy_has("b_factory") or _enemy_has("b_barracks") or _enemy_has("b_refinery"):
			saw_producer = true

		for b in get_nodes_in_group("buildings"):
			if int(b.get("team")) != GameConstants.Team.ENEMY:
				continue
			if not b.has_method("get_queue_snapshot"):
				continue
			var q: Array = b.get_queue_snapshot()
			if q.is_empty():
				continue
			saw_queue = true
			if float(q[0].get("remaining", 99)) > 0.2:
				b.set_front_job_remaining(0.1)

		# Once a wave is out, boost DPS so CY damage is observable headless
		if int(ai.waves_launched) >= 1:
			for u in get_nodes_in_group("team_enemy"):
				if u.is_in_group("units") and float(u.get("dps")) > 0.0:
					u.dps = maxf(float(u.dps), 70.0)
					u.move_speed = maxf(float(u.move_speed), 200.0)
					if u.has_method("command_attack"):
						u.command_attack(player_cy)

		var damaged: bool = (
			is_instance_valid(player_cy)
			and float(player_cy.hp) < hp_at_start - 1.0
		)
		var army_ok: bool = _enemy_combat_count() >= 3 or int(ai.combat_army_peak) >= 3
		var wave_ok: bool = int(ai.waves_launched) >= 1
		var built_ok: bool = saw_producer and (saw_queue or _enemy_has("b_factory") or _enemy_has("b_barracks"))

		if built_ok and wave_ok and (damaged or army_ok):
			print(
				"[smoke_ai] OK — producer=%s queue=%s waves=%d army=%d cy=%.0f→%.0f (%.1fs)"
				% [
					saw_producer,
					saw_queue,
					ai.waves_launched,
					_enemy_combat_count(),
					hp_at_start,
					player_cy.hp if is_instance_valid(player_cy) else 0.0,
					elapsed,
				]
			)
			quit(0)
			return

	push_error(
		"[smoke_ai] timeout producer=%s queue=%s waves=%d army=%d cy=%.1f"
		% [
			saw_producer,
			saw_queue,
			ai.waves_launched,
			_enemy_combat_count(),
			player_cy.hp if is_instance_valid(player_cy) else -1.0,
		]
	)
	quit(1)


func _enemy_has(building_id: String) -> bool:
	for b in get_nodes_in_group("buildings"):
		if int(b.get("team")) == GameConstants.Team.ENEMY and str(b.get("building_id")) == building_id:
			if b.get("alive") != false:
				return true
	return false


func _enemy_combat_count() -> int:
	var n := 0
	for u in get_nodes_in_group("team_enemy"):
		if not u.is_in_group("units"):
			continue
		if str(u.get("unit_id")) == "u_harvester":
			continue
		if float(u.get("dps")) > 0.0 and u.get("alive") != false:
			n += 1
	return n
