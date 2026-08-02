extends SceneTree
## S14 smoke: validate campaign JSON + unlock progression.
## Run: godot --headless --path . -s res://scripts/smoke_campaign.gd

const CampaignDB := preload("res://scripts/campaign_db.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[smoke_campaign] starting")
	var camp_ids := CampaignDB.list_campaign_ids()
	if camp_ids.is_empty():
		push_error("[smoke_campaign] no campaigns in data/campaigns")
		quit(1)
		return
	if not camp_ids.has("rise_of_sand"):
		push_error("[smoke_campaign] rise_of_sand missing")
		quit(1)
		return

	var errors := CampaignDB.validate_campaign("rise_of_sand")
	if not errors.is_empty():
		for e in errors:
			push_error("[smoke_campaign] %s" % e)
		quit(1)
		return

	var camp := CampaignDB.load_campaign("rise_of_sand")
	var ids := CampaignDB.mission_ids(camp)
	print("[smoke_campaign] campaign=%s missions=%d" % [camp.get("title"), ids.size()])

	# Isolated progress file
	var tmp := "user://smoke_campaign_progress_%d.json" % Time.get_ticks_msec()
	CampaignDB.progress_path = tmp
	CampaignDB.reset_campaign_progress("rise_of_sand")

	if CampaignDB.next_playable("rise_of_sand") != ids[0]:
		push_error("[smoke_campaign] next should be first mission")
		quit(1)
		return
	if not CampaignDB.is_unlocked("rise_of_sand", ids[0]):
		push_error("[smoke_campaign] first mission not unlocked")
		quit(1)
		return
	if ids.size() > 1 and CampaignDB.is_unlocked("rise_of_sand", ids[1]):
		push_error("[smoke_campaign] second mission should start locked")
		quit(1)
		return

	var next := CampaignDB.mark_won("rise_of_sand", ids[0])
	if next != ids[1]:
		push_error("[smoke_campaign] mark_won next=%s expected %s" % [next, ids[1]])
		quit(1)
		return
	if not CampaignDB.is_completed("rise_of_sand", ids[0]):
		push_error("[smoke_campaign] first not marked complete")
		quit(1)
		return
	if not CampaignDB.is_unlocked("rise_of_sand", ids[1]):
		push_error("[smoke_campaign] second not unlocked after win")
		quit(1)
		return
	if CampaignDB.next_playable("rise_of_sand") != ids[1]:
		push_error("[smoke_campaign] next_playable should be second")
		quit(1)
		return

	# Unlock chain through end
	for i in range(1, ids.size()):
		var n2 := CampaignDB.mark_won("rise_of_sand", ids[i])
		if i + 1 < ids.size():
			if n2 != ids[i + 1]:
				push_error("[smoke_campaign] chain break at %s" % ids[i])
				quit(1)
				return
		else:
			if n2 != "":
				push_error("[smoke_campaign] finale should return empty next")
				quit(1)
				return

	if CampaignDB.next_playable("rise_of_sand") != ids[ids.size() - 1]:
		push_error("[smoke_campaign] after complete, next should be last")
		quit(1)
		return

	# Load finale mission into main (smoke path; AI off via smoke_ prefix)
	OS.set_environment("SANDSPIRE_CAMPAIGN", "rise_of_sand")
	OS.set_environment("SANDSPIRE_MISSION", ids[ids.size() - 1])
	# Progress already unlocked all
	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("[smoke_campaign] main load failed")
		quit(1)
		return
	for i in 20:
		await process_frame

	var root := current_scene
	var sk: Node = root.get_node("SkirmishConfig")
	var mission: Node = root.get_node("Mission")
	if str(sk.campaign_id) != "rise_of_sand":
		push_error("[smoke_campaign] campaign_id not set on skirmish")
		quit(1)
		return
	if str(mission.mission_id) != ids[ids.size() - 1]:
		push_error("[smoke_campaign] finale mission not loaded (%s)" % mission.mission_id)
		quit(1)
		return
	if not mission.has_briefing():
		push_error("[smoke_campaign] finale briefing missing")
		quit(1)
		return
	var base_nodes := get_nodes_in_group("enemy_base")
	if base_nodes.size() < 2:
		push_error("[smoke_campaign] finale expected enemy_base tags (got %d)" % base_nodes.size())
		quit(1)
		return

	# Cleanup temp progress
	if FileAccess.file_exists(tmp):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	CampaignDB.progress_path = CampaignDB.DEFAULT_PROGRESS_PATH

	print(
		"[smoke_campaign] OK — %d missions validated, unlock chain + finale load (%s)"
		% [ids.size(), mission.mission_id]
	)
	quit(0)
