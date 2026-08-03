extends SceneTree
## Camera clamp: wide/zoomed-out views must not stick to the west edge.
## Run: godot --headless --path . -s res://scripts/smoke_camera.gd

const Cam := preload("res://scripts/rts_camera.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[smoke_camera] starting")
	var map_w := float(GameConstants.MAP_WIDTH * GameConstants.TILE_SIZE)  # 1536
	var map_h := float(GameConstants.MAP_HEIGHT * GameConstants.TILE_SIZE)  # 1152

	# Simulated 1920x1080 @ zoom 1 → half_x=960 → old clampf stuck at lo=960
	var stuck: float = Cam.clamp_axis(560.0, 960.0, 0.0, map_w)
	if not is_equal_approx(stuck, map_w * 0.5):
		push_error("[smoke_camera] wide view should center X, got %.1f" % stuck)
		quit(1)
		return

	var zoomed: float = Cam.clamp_axis(100.0, 1600.0, 0.0, map_w)
	if not is_equal_approx(zoomed, map_w * 0.5):
		push_error("[smoke_camera] oversize half should center, got %.1f" % zoomed)
		quit(1)
		return

	var east: float = Cam.clamp_axis(2000.0, 400.0, 0.0, map_w)
	if not is_equal_approx(east, map_w - 400.0):
		push_error("[smoke_camera] east clamp wrong %.1f (want %.1f)" % [east, map_w - 400.0])
		quit(1)
		return
	var west: float = Cam.clamp_axis(-50.0, 400.0, 0.0, map_w)
	if not is_equal_approx(west, 400.0):
		push_error("[smoke_camera] west clamp wrong %.1f" % west)
		quit(1)
		return

	var y_c: float = Cam.clamp_axis(0.0, 900.0, 0.0, map_h)
	if not is_equal_approx(y_c, map_h * 0.5):
		push_error("[smoke_camera] tall view should center Y")
		quit(1)
		return

	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("[smoke_camera] main load failed")
		quit(1)
		return
	for i in 20:
		await physics_frame

	var root := current_scene
	var cam: Camera2D = root.get_node("RtsCamera")
	var ai: Node = root.get_node_or_null("AiController")
	if ai:
		ai.enabled = false
	var worm: Node = root.get_node_or_null("Sandworm")
	if worm:
		worm.enabled = false

	var map_size: Vector2 = root.get_node("WorldMap").map_size_px()
	cam.configure_bounds(map_size)
	cam.zoom = Vector2(1.2, 1.2)
	cam.jump_to(Vector2(200, map_size.y * 0.5))
	var start_x: float = cam.global_position.x

	for i in 40:
		cam.global_position.x += 40.0
		cam.jump_to(cam.global_position)
		await physics_frame

	var end_x: float = cam.global_position.x
	if end_x <= start_x + 80.0:
		push_error("[smoke_camera] failed to pan east (start=%.0f end=%.0f)" % [start_x, end_x])
		quit(1)
		return
	if end_x < map_size.x * 0.45:
		push_error("[smoke_camera] east travel too shallow end_x=%.0f map_w=%.0f" % [end_x, map_size.x])
		quit(1)
		return

	cam.zoom = Vector2(0.4, 0.4)
	cam.jump_to(Vector2(50, 50))
	var cx: float = cam.global_position.x
	if cx < map_size.x * 0.35:
		push_error("[smoke_camera] zoomed-out clamp stuck west at %.0f" % cx)
		quit(1)
		return

	print("[smoke_camera] OK — clamp centers when oversized; east pan works")
	quit(0)
