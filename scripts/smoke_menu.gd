extends SceneTree
## S16+ smoke: main menu, skirmish lobby, canyon map load.
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
	var lobby: Node = root.get_node_or_null("SkirmishLobby")
	if lobby == null or not lobby.has_method("open_lobby"):
		push_error("[smoke_menu] SkirmishLobby missing")
		quit(1)
		return
	lobby.open_lobby()
	await process_frame
	if not lobby.visible:
		push_error("[smoke_menu] lobby not visible")
		quit(1)
		return
	var map_pick: OptionButton = lobby.get_node_or_null("Panel/MapPick")
	if map_pick == null or map_pick.item_count < 2:
		push_error("[smoke_menu] map picker needs 2 maps")
		quit(1)
		return
	print("[smoke_menu] lobby OK maps=%d" % map_pick.item_count)

	# Canyon skirmish load
	OS.set_environment("SANDSPIRE_CAMPAIGN", "")
	OS.set_environment("SANDSPIRE_MISSION", "")
	OS.set_environment("SANDSPIRE_PLAYER", "coilward")
	OS.set_environment("SANDSPIRE_ENEMY", "ashveil")
	OS.set_environment("SANDSPIRE_DIFFICULTY", "easy")
	OS.set_environment("SANDSPIRE_MAP", "canyon")
	err = change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("[smoke_menu] skirmish load failed")
		quit(1)
		return
	for i in 20:
		await process_frame
	var skirmish := current_scene
	if skirmish == null:
		push_error("[smoke_menu] skirmish null")
		quit(1)
		return
	var sk: Node = skirmish.get_node_or_null("SkirmishConfig")
	var wm: Node = skirmish.get_node_or_null("WorldMap")
	if sk == null or str(sk.player_faction) != "coilward" or str(sk.map_id) != "canyon":
		push_error("[smoke_menu] skirmish config not applied (p=%s map=%s)" % [
			sk.player_faction if sk else "?",
			sk.map_id if sk else "?",
		])
		quit(1)
		return
	if wm == null or str(wm.map_layout) != "canyon":
		push_error("[smoke_menu] canyon layout not on WorldMap")
		quit(1)
		return
	# Canyon should have spice corridor
	var spice_cells := 0
	for y in range(8, 28):
		for x in range(21, 27):
			if int(wm.get_spice_at(Vector2i(x, y))) > 0:
				spice_cells += 1
	if spice_cells < 10:
		push_error("[smoke_menu] canyon spice corridor too small (%d)" % spice_cells)
		quit(1)
		return

	print("[smoke_menu] OK — %s + lobby + canyon skirmish" % Version.display_string())
	quit(0)
