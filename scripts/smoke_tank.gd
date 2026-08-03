extends SceneTree
## Tank sprite loads and battle tanks use texture (not placeholder-only).
## Run: godot --headless --path . -s res://scripts/smoke_tank.gd


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[smoke_tank] starting")
	var path := "res://assets/units/tank_aureate.png"
	if not ResourceLoader.exists(path):
		push_error("[smoke_tank] missing %s" % path)
		quit(1)
		return
	var tex: Texture2D = load(path) as Texture2D
	if tex == null or tex.get_width() < 32 or tex.get_height() < 16:
		push_error("[smoke_tank] bad texture dims")
		quit(1)
		return

	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("[smoke_tank] main load failed")
		quit(1)
		return
	for i in 16:
		await physics_frame

	var root := current_scene
	var ai: Node = root.get_node_or_null("AiController")
	if ai:
		ai.enabled = false
	var units_root: Node2D = root.get_node("Units")
	var scene := preload("res://scenes/unit.tscn")
	var u: CharacterBody2D = scene.instantiate()
	u.unit_id = "u_tank"
	u.team = GameConstants.Team.PLAYER
	u.global_position = Vector2(400, 400)
	units_root.add_child(u)
	for i in 4:
		await physics_frame

	if not bool(u.get("_use_tank_sprite")):
		push_error("[smoke_tank] u_tank should use tank sprite")
		quit(1)
		return
	if u.get("_sprite") == null:
		push_error("[smoke_tank] sprite texture not bound")
		quit(1)
		return

	# Facing follows velocity (+X sprite → angle 0 when moving right)
	u.velocity = Vector2(120, 0)
	u._update_facing()
	if absf(float(u.get("_facing"))) > 0.2:
		push_error("[smoke_tank] facing should be ~0 when moving +X, got %s" % str(u.get("_facing")))
		quit(1)
		return
	u.velocity = Vector2(0, 120)
	u._update_facing()
	if absf(float(u.get("_facing")) - PI * 0.5) > 0.25:
		push_error("[smoke_tank] facing should be ~PI/2 when moving +Y, got %s" % str(u.get("_facing")))
		quit(1)
		return

	print("[smoke_tank] OK — texture %dx%d, facing wired" % [tex.get_width(), tex.get_height()])
	quit(0)
