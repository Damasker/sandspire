class_name UnitDatabase
extends Object
## Loads data/units/*.json once.

static var _cache: Dictionary = {}
static var _loaded: bool = false


static func get_unit(unit_id: String) -> Dictionary:
	_ensure_loaded()
	if _cache.has(unit_id):
		return _cache[unit_id]
	return {"id": unit_id, "name": unit_id, "speed": 140.0}


static func all_ids() -> Array:
	_ensure_loaded()
	return _cache.keys()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open("res://data/units")
	if dir == null:
		push_warning("UnitDatabase: res://data/units missing")
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var path := "res://data/units/%s" % file_name
			var text := FileAccess.get_file_as_string(path)
			var parsed: Variant = JSON.parse_string(text)
			if typeof(parsed) == TYPE_DICTIONARY:
				var d: Dictionary = parsed
				var id: String = str(d.get("id", file_name.get_basename()))
				_cache[id] = d
		file_name = dir.get_next()
	dir.list_dir_end()
