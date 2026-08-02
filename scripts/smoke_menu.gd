extends SceneTree
## S16 smoke: main menu + version + campaign navigation stubs.
## Run: godot --headless --path . -s res://scripts/smoke_menu.gd

const Version := preload("res://scripts/version.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[smoke_menu] starting")
	if Version.VERSION == "" or not Version.display_string().contains("Sandspire"):
		push_error("[smoke_menu] version string bad")
		quit(1)
		return

	var err := change_scene_to_file("res://scenes/main_menu.tscn")
	if err != OK:
		push_error("[smoke_menu] main_menu load failed")
		quit(1)
		return
	for i in 12:
		await process_frame

	var root := current_scene
	if root == null:
		push_error("[smoke_menu] null scene")
		quit(1)
		return
	var ver := root.get_node_or_null("Panel/Version") as Label
	if ver == null or not str(ver.text).contains(Version.VERSION):
		push_error("[smoke_menu] version label missing: %s" % (ver.text if ver else "null"))
		quit(1)
		return
	for need in ["Panel/Campaign", "Panel/Skirmish", "Panel/Options", "Panel/Quit"]:
		if root.get_node_or_null(need) == null:
			push_error("[smoke_menu] missing %s" % need)
			quit(1)
			return
	if root.get_node_or_null("GameOptions") == null or root.get_node_or_null("OptionsPanel") == null:
		push_error("[smoke_menu] options nodes missing")
		quit(1)
		return

	# Campaign menu reachable
	err = change_scene_to_file("res://scenes/campaign_menu.tscn")
	if err != OK:
		push_error("[smoke_menu] campaign_menu failed")
		quit(1)
		return
	for i in 10:
		await process_frame
	var camp := current_scene
	if camp == null or camp.get_node_or_null("Panel/MissionList") == null:
		push_error("[smoke_menu] campaign list missing")
		quit(1)
		return

	print("[smoke_menu] OK — %s + menu + campaign picker" % Version.display_string())
	quit(0)
