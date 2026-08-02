extends SceneTree
## S13 smoke: mission JSON load, harvest progress, destroy win, save/load.
## Run: godot --headless --path . -s res://scripts/smoke_mission.gd

const COMBAT_TIMEOUT := 45.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[smoke_mission] starting")
	OS.set_environment("SANDSPIRE_MISSION", "m01_first_blood")

	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("[smoke_mission] main load failed")
		quit(1)
		return

	for i in 20:
		await process_frame

	var root := current_scene
	var mission: Node = root.get_node("Mission")
	var sk: Node = root.get_node("SkirmishConfig")
	var economy: Node = root.get_node("Economy")
	var save_game: Node = root.get_node("SaveGame")
	var units: Node2D = root.get_node("Units")

	if str(sk.mission_id) != "m01_first_blood":
		push_error("[smoke_mission] mission_id=%s" % sk.mission_id)
		quit(1)
		return
	if str(mission.mission_id) != "m01_first_blood":
		push_error("[smoke_mission] Mission.mission_id=%s" % mission.mission_id)
		quit(1)
		return
	if not mission.has_briefing():
		push_error("[smoke_mission] briefing missing")
		quit(1)
		return
	if str(sk.player_faction) != "aureate" or str(sk.enemy_faction) != "ashveil":
		push_error("[smoke_mission] factions not applied from mission")
		quit(1)
		return

	# Harvest objective progress via lifetime_earned
	economy.add_credits(120)
	for i in 5:
		await process_frame
	var lines: PackedStringArray = mission.objective_lines()
	var harvest_done := false
	for line in lines:
		if String(line).contains("Harvest") and String(line).begins_with("[x]"):
			harvest_done = true
	if economy.lifetime_earned < 100:
		push_error("[smoke_mission] lifetime_earned=%d" % economy.lifetime_earned)
		quit(1)
		return
	if not harvest_done:
		# optional objective — still require tracker to mark done
		push_error("[smoke_mission] harvest objective not marked done: %s" % " | ".join(lines))
		quit(1)
		return
	print("[smoke_mission] harvest objective OK (earned=%d)" % economy.lifetime_earned)

	# Save / load round-trip (credits + mission id)
	var credits_before := int(economy.credits)
	if not save_game.save_slot(0):
		push_error("[smoke_mission] save_slot failed")
		quit(1)
		return
	economy.credits = 1
	economy.credits_changed.emit(1)
	if not save_game.load_slot(0):
		push_error("[smoke_mission] load_slot failed")
		quit(1)
		return
	for i in 8:
		await process_frame
	if int(economy.credits) != credits_before:
		push_error("[smoke_mission] load credits %d != %d" % [economy.credits, credits_before])
		quit(1)
		return
	if str(mission.mission_id) != "m01_first_blood":
		push_error("[smoke_mission] mission lost after load")
		quit(1)
		return
	print("[smoke_mission] save/load OK credits=%d" % economy.credits)

	# Survive-type tracker smoke (in-memory objective injection)
	mission.mission_def["objectives"] = [
		{"id": "survive_bit", "type": "survive", "seconds": 0.05, "required": false, "label": "Hold briefly"},
		{"id": "destroy_camp", "type": "destroy", "group": "enemy_camp", "count": 1, "required": true, "label": "Destroy camp"},
	]
	mission._build_trackers_from_def()
	mission.elapsed = 0.0
	mission.completed = false
	mission.failed = false
	for i in 10:
		await process_frame
	var survived := false
	for oid in mission._objectives.keys():
		var row: Dictionary = mission._objectives[oid]
		if str(row["def"].get("type")) == "survive" and bool(row["done"]):
			survived = true
	if not survived:
		push_error("[smoke_mission] survive objective did not complete")
		quit(1)
		return
	print("[smoke_mission] survive objective OK")

	# Win: destroy camp
	var camp: Node = null
	for b in get_nodes_in_group("enemy_camp"):
		camp = b
		break
	if camp == null:
		push_error("[smoke_mission] camp missing after load")
		quit(1)
		return
	camp.hp = 80.0
	camp.max_hp = 80.0
	for u in units.get_children():
		if int(u.get("team")) != GameConstants.Team.PLAYER:
			continue
		if u.is_in_group("harvesters"):
			continue
		if "dps" in u:
			u.dps = 90.0
			u.attack_range = 200.0
			u.move_speed = 220.0
		if u.has_method("command_attack"):
			u.command_attack(camp)

	var elapsed := 0.0
	while elapsed < COMBAT_TIMEOUT:
		await physics_frame
		elapsed += 1.0 / 60.0
		if mission.completed and not mission.failed:
			var banner := root.get_node_or_null("HUD/Victory") as Label
			print(
				"[smoke_mission] OK — win after %.1fs text=%s banner=%s"
				% [elapsed, mission.outcome_text, banner.visible if banner else false]
			)
			quit(0)
			return

	push_error(
		"[smoke_mission] timeout completed=%s failed=%s camp=%s"
		% [mission.completed, mission.failed, camp.hp if is_instance_valid(camp) else "gone"]
	)
	quit(1)
