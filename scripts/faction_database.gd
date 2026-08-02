class_name FactionDatabase
extends Object
## Loads data/factions/*.json (Aureate, Ashveil, Coilward).

static var _cache: Dictionary = {}
static var _loaded: bool = false
const DEFAULT_FACTION := "aureate"


static func get_faction(faction_id: String = DEFAULT_FACTION) -> Dictionary:
	_ensure_loaded()
	if _cache.has(faction_id):
		return _cache[faction_id]
	return {
		"id": faction_id,
		"name": faction_id.capitalize(),
		"short_name": faction_id.capitalize(),
		"accent": [0.86, 0.68, 0.22],
		"roles": {},
		"produces": {},
		"building_mods": {},
	}


static func accent_color(faction_id: String = DEFAULT_FACTION) -> Color:
	var d := get_faction(faction_id)
	var a: Variant = d.get("accent", [0.86, 0.68, 0.22])
	if typeof(a) == TYPE_ARRAY and a.size() >= 3:
		return Color(float(a[0]), float(a[1]), float(a[2]))
	return Color(0.86, 0.68, 0.22)


static func display_name(faction_id: String = DEFAULT_FACTION) -> String:
	return str(get_faction(faction_id).get("name", "House Aureate"))


static func short_name(faction_id: String = DEFAULT_FACTION) -> String:
	return str(get_faction(faction_id).get("short_name", "Aureate"))


static func role_unit(faction_id: String, role: String) -> String:
	var roles: Variant = get_faction(faction_id).get("roles", {})
	if typeof(roles) == TYPE_DICTIONARY and roles.has(role):
		return str(roles[role])
	return ""


static func produces_for(faction_id: String, building_id: String) -> Array:
	var prod: Variant = get_faction(faction_id).get("produces", {})
	if typeof(prod) != TYPE_DICTIONARY:
		return []
	var list: Variant = prod.get(building_id, [])
	if typeof(list) != TYPE_ARRAY:
		return []
	return list


static func building_mods(faction_id: String, building_id: String) -> Dictionary:
	var mods: Variant = get_faction(faction_id).get("building_mods", {})
	if typeof(mods) != TYPE_DICTIONARY:
		return {}
	var m: Variant = mods.get(building_id, {})
	if typeof(m) != TYPE_DICTIONARY:
		return {}
	return m


static func building_mod_float(faction_id: String, building_id: String, key: String, default_value: float) -> float:
	var m := building_mods(faction_id, building_id)
	if m.has(key):
		return float(m[key])
	return default_value


static func ai_unit_ids(faction_id: String) -> Array:
	var raw: Variant = get_faction(faction_id).get("ai_units", [])
	if typeof(raw) != TYPE_ARRAY:
		return []
	return raw


static func all_ids() -> Array:
	_ensure_loaded()
	return _cache.keys()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open("res://data/factions")
	if dir == null:
		push_warning("FactionDatabase: res://data/factions missing")
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var path := "res://data/factions/%s" % file_name
			var text := FileAccess.get_file_as_string(path)
			var parsed: Variant = JSON.parse_string(text)
			if typeof(parsed) == TYPE_DICTIONARY:
				var d: Dictionary = parsed
				var id: String = str(d.get("id", file_name.get_basename()))
				_cache[id] = d
		file_name = dir.get_next()
	dir.list_dir_end()
