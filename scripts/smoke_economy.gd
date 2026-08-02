extends SceneTree
## Headless S2 smoke: wait until harvester unloads credits.
## Run: godot --headless --path . -s res://scripts/smoke_economy.gd

const TIMEOUT_SEC := 45.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[smoke_economy] starting")
	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("[smoke_economy] failed to load main.tscn: %s" % err)
		quit(1)
		return

	# Let _ready / deferred binds run
	for i in 10:
		await physics_frame

	var root := current_scene
	if root == null:
		push_error("[smoke_economy] no current_scene")
		quit(1)
		return

	var economy: Node = root.get_node_or_null("Economy")
	var buildings: Node = root.get_node_or_null("Buildings")
	var harvesters := get_nodes_in_group("harvesters")
	if economy == null:
		push_error("[smoke_economy] Economy missing")
		quit(1)
		return
	if buildings == null or buildings.get_child_count() < 1:
		push_error("[smoke_economy] no refinery spawned")
		quit(1)
		return
	if harvesters.is_empty():
		push_error("[smoke_economy] no harvester")
		quit(1)
		return

	# Speed up harvest for CI (does not change default gameplay scene data)
	for h in harvesters:
		h.cargo_capacity = 40
		h.harvest_rate = 120.0
		h.unload_rate = 160.0
		h.move_speed = 260.0
		h.auto_harvest = true
		if h.state == h.State.IDLE:
			h._enter(h.State.SEEK)

	var start_credits: int = economy.credits
	print("[smoke_economy] start_credits=%d harvesters=%d refineries=%d spice=%d" % [
		start_credits,
		harvesters.size(),
		buildings.get_child_count(),
		root.get_node("WorldMap").total_spice_remaining(),
	])

	var elapsed := 0.0
	while elapsed < TIMEOUT_SEC:
		await physics_frame
		elapsed += 1.0 / 60.0
		if economy.credits > start_credits:
			print("[smoke_economy] credits=%d after ~%.1fs OK" % [economy.credits, elapsed])
			quit(0)
			return

	push_error("[smoke_economy] timeout: credits still %d" % economy.credits)
	for h in harvesters:
		print("[smoke_economy] harvester state=%s cargo=%s pos=%s target=%s" % [
			h.state, h.cargo, h.global_position, h._target
		])
	quit(1)
