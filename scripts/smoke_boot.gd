extends SceneTree
## Headless boot smoke: load main scene, tick frames, exit 0/1.
## Run: godot --headless --path . -s res://scripts/smoke_boot.gd


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[smoke] Sandspire boot starting")
	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("[smoke] failed to load main.tscn: %s" % err)
		quit(1)
		return
	for i in 5:
		await process_frame
	var root := current_scene
	if root == null:
		push_error("[smoke] current_scene is null")
		quit(1)
		return
	var units := root.get_node_or_null("Units")
	if units == null or units.get_child_count() < 1:
		push_error("[smoke] no demo units spawned")
		quit(1)
		return
	var ids := UnitDatabase.all_ids()
	if ids.size() < 20:
		push_error("[smoke] expected >=20 units (3 houses), got %d" % ids.size())
		quit(1)
		return
	for need in ["aureate", "ashveil", "coilward"]:
		if not FactionDatabase.all_ids().has(need):
			push_error("[smoke] faction missing: %s" % need)
			quit(1)
			return
	print("[smoke] units_in_db=%d demo_units=%d factions=%s" % [
		ids.size(), units.get_child_count(), ",".join(FactionDatabase.all_ids())
	])
	print("[smoke] OK")
	quit(0)
