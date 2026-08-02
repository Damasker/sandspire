extends RefCounted
## Campaign definitions + unlock progress (S14).
## Progress file: user://campaign_progress.json (overridable via progress_path).

const DEFAULT_PROGRESS_PATH := "user://campaign_progress.json"
const CAMPAIGN_DIR := "res://data/campaigns"
const MISSION_DIR := "res://data/missions"

## Tests may point this at a temp path.
static var progress_path: String = DEFAULT_PROGRESS_PATH


static func list_campaign_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var dir := DirAccess.open(CAMPAIGN_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".json"):
			out.append(name.get_basename())
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


static func load_campaign(campaign_id: String) -> Dictionary:
	var path := "%s/%s.json" % [CAMPAIGN_DIR, campaign_id]
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func mission_ids(campaign: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for m in campaign.get("missions", []):
		out.append(str(m))
	return out


static func load_mission_def(mission_id: String) -> Dictionary:
	var path := "%s/%s.json" % [MISSION_DIR, mission_id]
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func validate_mission_def(mission_id: String, def: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if def.is_empty():
		errors.append("%s: missing or bad JSON" % mission_id)
		return errors
	if str(def.get("id", "")) != mission_id:
		errors.append("%s: id mismatch (%s)" % [mission_id, def.get("id")])
	if str(def.get("title", "")) == "":
		errors.append("%s: missing title" % mission_id)
	var br: Dictionary = def.get("briefing", {})
	if str(br.get("text", "")) == "":
		errors.append("%s: missing briefing.text" % mission_id)
	if str(br.get("advisor", "")) == "":
		errors.append("%s: missing briefing.advisor" % mission_id)
	var objs: Array = def.get("objectives", [])
	if objs.is_empty():
		errors.append("%s: no objectives" % mission_id)
	var has_required := false
	for o in objs:
		if typeof(o) != TYPE_DICTIONARY:
			errors.append("%s: bad objective entry" % mission_id)
			continue
		var t := str(o.get("type", ""))
		if t not in ["destroy", "harvest", "survive"]:
			errors.append("%s: unknown objective type '%s'" % [mission_id, t])
		if bool(o.get("required", true)):
			has_required = true
	if not has_required:
		errors.append("%s: need at least one required objective" % mission_id)
	var pf := str(def.get("player_faction", ""))
	var ef := str(def.get("enemy_faction", ""))
	if not FactionDatabase.all_ids().has(pf):
		errors.append("%s: bad player_faction %s" % [mission_id, pf])
	if not FactionDatabase.all_ids().has(ef):
		errors.append("%s: bad enemy_faction %s" % [mission_id, ef])
	return errors


static func validate_campaign(campaign_id: String) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var camp := load_campaign(campaign_id)
	if camp.is_empty():
		errors.append("campaign missing: %s" % campaign_id)
		return errors
	var ids := mission_ids(camp)
	if ids.size() < 6 or ids.size() > 8:
		errors.append("%s: expected 6–8 missions, got %d" % [campaign_id, ids.size()])
	for mid in ids:
		var def := load_mission_def(mid)
		errors.append_array(validate_mission_def(mid, def))
	return errors


static func load_progress() -> Dictionary:
	if not FileAccess.file_exists(progress_path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(progress_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func save_progress(data: Dictionary) -> bool:
	var abs_dir := progress_path.get_base_dir()
	if abs_dir.begins_with("user://"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(abs_dir))
	var f := FileAccess.open(progress_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


static func _bucket(progress: Dictionary, campaign_id: String) -> Dictionary:
	var b: Variant = progress.get(campaign_id, {})
	if typeof(b) != TYPE_DICTIONARY:
		b = {}
	var bucket: Dictionary = b
	if not bucket.has("completed"):
		bucket["completed"] = []
	if not bucket.has("unlocked"):
		bucket["unlocked"] = []
	return bucket


static func ensure_progress(campaign_id: String) -> Dictionary:
	var progress := load_progress()
	var camp := load_campaign(campaign_id)
	var ids := mission_ids(camp)
	var bucket := _bucket(progress, campaign_id)
	var unlocked: Array = bucket.get("unlocked", [])
	if ids.size() > 0 and not unlocked.has(ids[0]):
		unlocked.append(ids[0])
	bucket["unlocked"] = unlocked
	if not bucket.has("completed"):
		bucket["completed"] = []
	progress[campaign_id] = bucket
	save_progress(progress)
	return progress


static func is_unlocked(campaign_id: String, mission_id: String) -> bool:
	var progress := ensure_progress(campaign_id)
	var bucket := _bucket(progress, campaign_id)
	var unlocked: Array = bucket.get("unlocked", [])
	return unlocked.has(mission_id)


static func is_completed(campaign_id: String, mission_id: String) -> bool:
	var progress := load_progress()
	var bucket := _bucket(progress, campaign_id)
	var completed: Array = bucket.get("completed", [])
	return completed.has(mission_id)


static func mark_won(campaign_id: String, mission_id: String) -> String:
	## Marks mission complete and unlocks the next. Returns next mission id (or "").
	var camp := load_campaign(campaign_id)
	var ids := mission_ids(camp)
	if ids.is_empty() or not ids.has(mission_id):
		return ""
	var progress := ensure_progress(campaign_id)
	var bucket := _bucket(progress, campaign_id)
	var completed: Array = bucket.get("completed", [])
	var unlocked: Array = bucket.get("unlocked", [])
	if not completed.has(mission_id):
		completed.append(mission_id)
	var idx := ids.find(mission_id)
	var next_id := ""
	if idx >= 0 and idx + 1 < ids.size():
		next_id = ids[idx + 1]
		if not unlocked.has(next_id):
			unlocked.append(next_id)
	bucket["completed"] = completed
	bucket["unlocked"] = unlocked
	progress[campaign_id] = bucket
	save_progress(progress)
	return next_id


static func next_playable(campaign_id: String) -> String:
	## First unlocked mission that is not completed; else last unlocked; else first.
	var camp := load_campaign(campaign_id)
	var ids := mission_ids(camp)
	if ids.is_empty():
		return ""
	var progress := ensure_progress(campaign_id)
	var bucket := _bucket(progress, campaign_id)
	var completed: Array = bucket.get("completed", [])
	var unlocked: Array = bucket.get("unlocked", [])
	for mid in ids:
		if unlocked.has(mid) and not completed.has(mid):
			return mid
	if not unlocked.is_empty():
		return str(unlocked[unlocked.size() - 1])
	return ids[0]


static func reset_campaign_progress(campaign_id: String) -> void:
	var progress := load_progress()
	progress.erase(campaign_id)
	save_progress(progress)
	ensure_progress(campaign_id)
