extends SceneTree
## S12 smoke: three-house balance invariants + AI difficulty profiles.
## Run: godot --headless --path . -s res://scripts/smoke_balance.gd

const SIGNATURES := {
	"aureate": ["u_siege", "u_msa"],
	"ashveil": ["ash_flame"],
	"coilward": ["coil_air"],
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[smoke_balance] starting")
	for fid in ["aureate", "ashveil", "coilward"]:
		var f := FactionDatabase.get_faction(fid)
		if str(f.get("id", "")) != fid:
			push_error("[smoke_balance] missing faction %s" % fid)
			quit(1)
			return
		if str(f.get("signature", "")) == "":
			push_error("[smoke_balance] faction %s missing signature string" % fid)
			quit(1)
			return
		for uid in SIGNATURES[fid]:
			var u := UnitDatabase.get_unit(uid)
			if str(u.get("id", "")) != uid:
				push_error("[smoke_balance] signature unit missing %s" % uid)
				quit(1)
				return
			if str(u.get("faction", "")) != fid:
				push_error("[smoke_balance] %s wrong faction tag" % uid)
				quit(1)
				return

	# Unique signatures
	if float(UnitDatabase.get_unit("ash_flame").get("splash_radius", 0)) <= 0.0:
		push_error("[smoke_balance] ash_flame needs splash")
		quit(1)
		return
	if not bool(UnitDatabase.get_unit("coil_air").get("flying", false)):
		push_error("[smoke_balance] coil_air must fly")
		quit(1)
		return
	var coil_turret: Dictionary = FactionDatabase.building_mods("coilward", "b_turret")
	if float(coil_turret.get("dps", 0)) <= float(BuildingDatabase.get_building("b_turret").get("dps", 18)):
		push_error("[smoke_balance] coilward turret should out-DPS baseline")
		quit(1)
		return

	var ids: Array = UnitDatabase.all_ids()
	var combat_costs: Array[int] = []
	for uid_v in ids:
		var uid := str(uid_v)
		var u := UnitDatabase.get_unit(uid)
		var cost := int(u.get("cost", -1))
		var hp := float(u.get("hp", 0))
		var dps := float(u.get("dps", -1))
		var bt := float(u.get("build_time", 0))
		var is_harv := uid.contains("harvester")
		if bt <= 0.0:
			push_error("[smoke_balance] %s build_time must be > 0" % uid)
			quit(1)
			return
		if hp <= 0.0 or hp > 600.0:
			push_error("[smoke_balance] %s hp out of band (%.0f)" % [uid, hp])
			quit(1)
			return
		if is_harv:
			if cost != 0:
				push_error("[smoke_balance] harvester %s cost must be 0" % uid)
				quit(1)
				return
			if dps != 0.0:
				push_error("[smoke_balance] harvester %s dps must be 0" % uid)
				quit(1)
				return
		else:
			if cost <= 0:
				push_error("[smoke_balance] combat unit %s cost must be > 0" % uid)
				quit(1)
				return
			if dps <= 0.0 or dps > 50.0:
				push_error("[smoke_balance] %s dps out of band (%.1f)" % [uid, dps])
				quit(1)
				return
			combat_costs.append(cost)

	# Role peers should not be wildly cost-skewed (trike band)
	var trike_costs := [
		int(UnitDatabase.get_unit("u_trike").get("cost")),
		int(UnitDatabase.get_unit("ash_trike").get("cost")),
		int(UnitDatabase.get_unit("coil_trike").get("cost")),
	]
	trike_costs.sort()
	if trike_costs[2] > trike_costs[0] * 1.6:
		push_error("[smoke_balance] trike cost spread too wide %s" % str(trike_costs))
		quit(1)
		return

	var tank_costs := [
		int(UnitDatabase.get_unit("u_tank").get("cost")),
		int(UnitDatabase.get_unit("ash_tank").get("cost")),
		int(UnitDatabase.get_unit("coil_tank").get("cost")),
	]
	tank_costs.sort()
	if tank_costs[2] > tank_costs[0] * 1.35:
		push_error("[smoke_balance] tank cost spread too wide %s" % str(tank_costs))
		quit(1)
		return

	# AI difficulty profiles
	for diff in ["easy", "normal", "hard"]:
		var path := "res://data/ai/%s.json" % diff
		if not FileAccess.file_exists(path):
			push_error("[smoke_balance] missing AI profile %s" % diff)
			quit(1)
			return
		var prof: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(prof) != TYPE_DICTIONARY:
			push_error("[smoke_balance] bad AI json %s" % diff)
			quit(1)
			return
		var p: Dictionary = prof
		if int(p.get("starting_credits", 0)) <= 0:
			push_error("[smoke_balance] %s needs starting_credits" % diff)
			quit(1)
			return
		if float(p.get("wave_cooldown", 0)) <= 0.0:
			push_error("[smoke_balance] %s needs wave_cooldown" % diff)
			quit(1)
			return
	var easy_c := int(JSON.parse_string(FileAccess.get_file_as_string("res://data/ai/easy.json"))["starting_credits"])
	var hard_c := int(JSON.parse_string(FileAccess.get_file_as_string("res://data/ai/hard.json"))["starting_credits"])
	if not (easy_c < 500 and hard_c > 500):
		push_error("[smoke_balance] easy/hard credit ordering wrong (%d/%d)" % [easy_c, hard_c])
		quit(1)
		return

	# Short scene check: telemetry + difficulty wiring
	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("[smoke_balance] main load failed")
		quit(1)
		return
	for i in 15:
		await process_frame
	var root := current_scene
	var sk: Node = root.get_node_or_null("SkirmishConfig")
	var tel: Node = root.get_node_or_null("CombatTelemetry")
	var ai: Node = root.get_node_or_null("AiController")
	if sk == null or tel == null:
		push_error("[smoke_balance] SkirmishConfig/CombatTelemetry missing")
		quit(1)
		return
	if str(sk.difficulty) == "":
		push_error("[smoke_balance] difficulty empty")
		quit(1)
		return
	if ai and str(ai.profile_id) != str(sk.difficulty):
		# main should sync profile from difficulty
		push_error("[smoke_balance] AI profile_id=%s != difficulty=%s" % [ai.profile_id, sk.difficulty])
		quit(1)
		return
	tel.refresh()
	if int(tel.player_count) < 1:
		push_error("[smoke_balance] telemetry expected player combat units")
		quit(1)
		return

	print(
		"[smoke_balance] OK — 3 houses, signatures, AI easy/normal/hard, telemetry P=%d/%d"
		% [tel.player_count, tel.player_value]
	)
	quit(0)
