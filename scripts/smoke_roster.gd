extends SceneTree
## S9 smoke: House Aureate roster data loads and production lists resolve.
## Run: godot --headless --path . -s res://scripts/smoke_roster.gd

const AUREATE_UNITS := [
	"u_infantry", "u_trooper_h", "u_harvester", "u_trike",
	"u_quad", "u_tank", "u_siege", "u_msa",
]
const CORE_BUILDINGS := [
	"b_conyard", "b_power", "b_refinery", "b_silo", "b_barracks",
	"b_factory", "b_turret", "b_radar",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[smoke_roster] starting")
	var faction := FactionDatabase.get_faction("aureate")
	if str(faction.get("id", "")) != "aureate":
		push_error("[smoke_roster] aureate faction missing")
		quit(1)
		return

	for uid in AUREATE_UNITS:
		var u := UnitDatabase.get_unit(uid)
		if str(u.get("id", "")) != uid:
			push_error("[smoke_roster] missing unit %s" % uid)
			quit(1)
			return
		if not u.has("cost") or not u.has("build_time"):
			push_error("[smoke_roster] unit %s missing cost/build_time" % uid)
			quit(1)
			return
		if str(u.get("faction", "")) != "aureate":
			push_error("[smoke_roster] unit %s not tagged aureate" % uid)
			quit(1)
			return

	for bid in CORE_BUILDINGS:
		var b := BuildingDatabase.get_building(bid)
		if str(b.get("id", "")) != bid and not b.has("name"):
			push_error("[smoke_roster] missing building %s" % bid)
			quit(1)
			return

	var barracks_prod: Array = BuildingDatabase.get_building("b_barracks").get("produces", [])
	for need in ["u_infantry", "u_trooper_h"]:
		if need not in barracks_prod:
			push_error("[smoke_roster] barracks missing %s" % need)
			quit(1)
			return

	var factory_prod: Array = BuildingDatabase.get_building("b_factory").get("produces", [])
	for need in ["u_trike", "u_quad", "u_tank", "u_siege", "u_msa"]:
		if need not in factory_prod:
			push_error("[smoke_roster] factory missing %s" % need)
			quit(1)
			return

	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("[smoke_roster] main load failed")
		quit(1)
		return
	for i in 12:
		await process_frame

	var root := current_scene
	var menu := root.get_node_or_null("HUD/BuildMenu")
	if menu == null:
		push_error("[smoke_roster] BuildMenu missing")
		quit(1)
		return

	# Spot-check enqueue of new roster units (funded)
	var economy: Node = root.get_node("Economy")
	economy.add_credits(5000)
	var bc: Node = root.get_node("BuildController")
	var barracks: Node = null
	for cell in [Vector2i(10, 18), Vector2i(14, 18), Vector2i(8, 16)]:
		barracks = bc.try_place_at("b_barracks", cell, true)
		if barracks:
			break
	if barracks == null:
		push_error("[smoke_roster] could not place barracks")
		quit(1)
		return
	if not barracks.enqueue_unit("u_trooper_h", true):
		push_error("[smoke_roster] enqueue heavy trooper failed")
		quit(1)
		return

	var factory: Node = null
	for cell in [Vector2i(12, 20), Vector2i(16, 20), Vector2i(10, 20)]:
		factory = bc.try_place_at("b_factory", cell, true)
		if factory:
			break
	if factory == null:
		push_error("[smoke_roster] could not place factory")
		quit(1)
		return
	for uid in ["u_trike", "u_siege", "u_msa"]:
		if not factory.enqueue_unit(uid, true):
			push_error("[smoke_roster] enqueue %s failed" % uid)
			quit(1)
			return

	print(
		"[smoke_roster] OK — %d aureate units, faction=%s, queued heavy+trike+siege+msa"
		% [AUREATE_UNITS.size(), FactionDatabase.short_name("aureate")]
	)
	quit(0)
