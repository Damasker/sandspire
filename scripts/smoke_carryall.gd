extends SceneTree
## Post-MVP smoke: carryall data + airlift FSM lifts harvester over sand (worm-safe while carried).
## Run: godot --headless --path . -s res://scripts/smoke_carryall.gd


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[smoke_carryall] starting")
	var def := UnitDatabase.get_unit("u_carryall")
	if str(def.get("id", "")) != "u_carryall":
		push_error("[smoke_carryall] missing u_carryall data")
		quit(1)
		return
	if not bool(def.get("flying", false)):
		push_error("[smoke_carryall] must be flying")
		quit(1)
		return
	if float(def.get("dps", -1)) != 0.0:
		push_error("[smoke_carryall] utility dps must be 0")
		quit(1)
		return
	if int(def.get("cost", 0)) <= 0:
		push_error("[smoke_carryall] cost must be > 0")
		quit(1)
		return

	for fid in ["aureate", "ashveil", "coilward"]:
		var prod: Array = FactionDatabase.produces_for(fid, "b_radar")
		if "u_carryall" not in prod:
			push_error("[smoke_carryall] %s Outpost must produce u_carryall" % fid)
			quit(1)
			return

	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("[smoke_carryall] main load failed")
		quit(1)
		return
	for i in 20:
		await physics_frame

	var root := current_scene
	var ai: Node = root.get_node_or_null("AiController")
	if ai:
		ai.enabled = false
	var worm: Node2D = root.get_node_or_null("Sandworm")
	if worm:
		worm.enabled = true

	var world: Node2D = root.get_node("WorldMap")
	var units_root: Node2D = root.get_node("Units")

	# Deterministic far job: west sand → east spice shelf
	var drop_cell := Vector2i(34, 18)
	var start_cell := Vector2i(8, 18)
	# Ensure drop has spice so seek stays valid
	var drop_idx := drop_cell.y * GameConstants.MAP_WIDTH + drop_cell.x
	if world.get_spice_at(drop_cell) <= 0:
		# Fall back to any spice, then park harvester far west of it
		drop_cell = world.find_nearest_spice_cell(world.cell_to_world_center(Vector2i(36, 18)))
		if drop_cell.x < 0:
			push_error("[smoke_carryall] no spice on map")
			quit(1)
			return
		start_cell = Vector2i(maxi(2, drop_cell.x - 18), drop_cell.y)

	var spice_pos: Vector2 = world.cell_to_world_center(drop_cell)
	var harv_start: Vector2 = world.cell_to_world_center(start_cell)
	# Nudge start further if still too close
	if harv_start.distance_to(spice_pos) < 400.0:
		harv_start = spice_pos + Vector2(-480, 0)
		harv_start.x = maxf(48.0, harv_start.x)

	var harv_scene := preload("res://scenes/harvester.tscn")
	var harv: CharacterBody2D = harv_scene.instantiate()
	harv.unit_id = "u_harvester"
	harv.team = GameConstants.Team.PLAYER
	harv.global_position = harv_start
	harv.auto_harvest = true
	units_root.add_child(harv)

	var carry_scene := preload("res://scenes/carryall.tscn")
	var carry: CharacterBody2D = carry_scene.instantiate()
	carry.unit_id = "u_carryall"
	carry.team = GameConstants.Team.PLAYER
	carry.global_position = harv_start + Vector2(-48, -48)
	units_root.add_child(carry)
	carry.auto_assist = true
	carry.assist_distance = 280.0
	carry.pickup_range = 72.0

	for i in 12:
		await physics_frame

	if harv.has_method("_bind_world"):
		harv._bind_world()
	# Pin a distant SEEK target without _enter() (which would re-pick nearest)
	harv.auto_harvest = true
	harv._harvest_cell = drop_cell
	harv.state = 1  # State.SEEK
	harv._manual_move = false
	harv.set_destination(spice_pos)

	var ground_dist := harv.global_position.distance_to(spice_pos)
	if ground_dist < 280.0:
		push_error("[smoke_carryall] test setup distance too short (%.0f)" % ground_dist)
		quit(1)
		return
	if not harv.wants_carryall_assist(280.0):
		push_error("[smoke_carryall] harvester should want assist")
		quit(1)
		return

	# Kick job discovery immediately
	if carry.has_method("_try_find_job"):
		carry._try_find_job()

	var lifted := false
	var dropped := false
	for i in 900:
		await physics_frame
		if bool(harv.carried):
			lifted = true
			if not bool(harv.flying):
				push_error("[smoke_carryall] carried harvester must be flying (worm-safe)")
				quit(1)
				return
			if worm and worm.has_method("force_emerge_at") and i % 30 == 0:
				worm.force_emerge_at(harv.global_position)
		if lifted and not bool(harv.carried) and int(carry.jobs_done) >= 1:
			dropped = true
			break

	if not lifted:
		push_error(
			"[smoke_carryall] never lifted (carry_state=%s jobs=%d)"
			% [str(carry.carry_state), int(carry.jobs_done)]
		)
		quit(1)
		return
	if not dropped:
		push_error("[smoke_carryall] never completed drop (jobs=%d)" % int(carry.jobs_done))
		quit(1)
		return

	var near_spice := harv.global_position.distance_to(spice_pos) < 96.0
	if not near_spice:
		push_error(
			"[smoke_carryall] drop too far from spice (d=%.0f)"
			% harv.global_position.distance_to(spice_pos)
		)
		quit(1)
		return

	if worm and int(worm.get("swallows")) > 0 and bool(harv.get("alive")) == false:
		push_error("[smoke_carryall] worm swallowed harvester during airlift")
		quit(1)
		return

	print("[smoke_carryall] OK — airlift FSM + worm-safe carry")
	quit(0)
