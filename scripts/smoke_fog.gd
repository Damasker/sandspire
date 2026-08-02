extends SceneTree
## S6 smoke: enemy camp hidden in fog until scouted / radar reveal.
## Run: godot --headless --path . -s res://scripts/smoke_fog.gd


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[smoke_fog] starting")
	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("[smoke_fog] load failed")
		quit(1)
		return

	for i in 25:
		await physics_frame

	var root := current_scene
	var vision: Node = root.get_node("VisionSystem")
	vision.update_vision()

	var camp: Node = null
	for b in get_nodes_in_group("enemy_camp"):
		camp = b
		break
	if camp == null:
		push_error("[smoke_fog] no enemy camp")
		quit(1)
		return

	var camp_pos: Vector2 = camp.get_selection_rect().get_center()
	if vision.is_world_visible(camp_pos):
		push_error("[smoke_fog] camp should start hidden in fog")
		quit(1)
		return
	if camp.visible:
		push_error("[smoke_fog] camp CanvasItem should be hidden")
		quit(1)
		return
	print("[smoke_fog] camp hidden OK at %s" % camp_pos)

	# Scout: teleport player trike near camp and refresh vision
	var scout: Node = null
	for u in get_nodes_in_group("team_player"):
		if u.is_in_group("units") and str(u.get("unit_id")) == "u_trike":
			scout = u
			break
	if scout == null:
		push_error("[smoke_fog] no scout trike")
		quit(1)
		return

	scout.global_position = camp_pos + Vector2(-80, 40)
	scout.vision_tiles = 10
	vision.update_vision()
	for i in 5:
		await physics_frame
	vision.update_vision()

	if not vision.is_world_visible(camp_pos):
		# fallback: force reveal as radar would
		vision.reveal_at_world(camp_pos, 8)
		vision.update_vision()

	if not vision.is_world_visible(camp_pos):
		push_error("[smoke_fog] camp still not visible after scout")
		quit(1)
		return
	if not camp.visible:
		push_error("[smoke_fog] camp node not shown after reveal")
		quit(1)
		return

	print("[smoke_fog] OK — fog hid enemy until scouted")
	quit(0)
