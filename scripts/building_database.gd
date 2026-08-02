class_name BuildingDatabase
extends Object
## Loads data/buildings/*.json once. Prereq helpers for tech tree.

static var _cache: Dictionary = {}
static var _loaded: bool = false


static func get_building(building_id: String) -> Dictionary:
	_ensure_loaded()
	if _cache.has(building_id):
		return _cache[building_id]
	return {"id": building_id, "name": building_id, "cost": 0, "footprint": [2, 2]}


static func all_ids() -> Array:
	_ensure_loaded()
	return _cache.keys()


static func footprint_of(building_id: String) -> Vector2i:
	var d := get_building(building_id)
	var fp: Variant = d.get("footprint", [2, 2])
	if typeof(fp) == TYPE_ARRAY and fp.size() >= 2:
		return Vector2i(int(fp[0]), int(fp[1]))
	return Vector2i(2, 2)


static func prereq_ids(building_id: String) -> Array[String]:
	var d := get_building(building_id)
	var raw: Variant = d.get("prereq", null)
	var out: Array[String] = []
	if raw == null or str(raw) == "" or str(raw) == "null":
		return out
	if typeof(raw) == TYPE_ARRAY:
		for item in raw:
			var s := str(item)
			if s != "" and s != "null":
				out.append(s)
	else:
		out.append(str(raw))
	return out


static func has_building_id(tree: SceneTree, building_id: String, team: int = GameConstants.Team.PLAYER) -> bool:
	for b in tree.get_nodes_in_group("buildings"):
		if not is_instance_valid(b):
			continue
		if b.get("alive") == false:
			continue
		if int(b.get("team")) != team:
			continue
		if str(b.get("building_id")) == building_id:
			return true
	return false


static func meets_prereqs(tree: SceneTree, building_id: String, team: int = GameConstants.Team.PLAYER) -> bool:
	for need in prereq_ids(building_id):
		if not has_building_id(tree, need, team):
			return false
	return true


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open("res://data/buildings")
	if dir == null:
		push_warning("BuildingDatabase: res://data/buildings missing")
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var path := "res://data/buildings/%s" % file_name
			var text := FileAccess.get_file_as_string(path)
			var parsed: Variant = JSON.parse_string(text)
			if typeof(parsed) == TYPE_DICTIONARY:
				var d: Dictionary = parsed
				var id: String = str(d.get("id", file_name.get_basename()))
				_cache[id] = d
		file_name = dir.get_next()
	dir.list_dir_end()
