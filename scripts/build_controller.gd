extends Node2D
## Placement ghost. Respects rock, overlap, prereqs, credits.

signal placement_started(building_id: String)
signal placement_finished(building_id: String, success: bool)
signal building_placed(building: Node)

@export var world_map_path: NodePath
@export var buildings_root_path: NodePath
@export var economy_path: NodePath
@export var power_grid_path: NodePath

var placing_id: String = ""
var _ghost_origin: Vector2i = Vector2i.ZERO
var _ghost_valid: bool = false
var _footprint: Vector2i = Vector2i(2, 2)


func is_placing() -> bool:
	return placing_id != ""


func can_start_place(building_id: String) -> bool:
	if not BuildingDatabase.meets_prereqs(get_tree(), building_id, GameConstants.Team.PLAYER):
		return false
	var def := BuildingDatabase.get_building(building_id)
	var cost := int(def.get("cost", 0))
	var economy := _economy()
	if economy and not economy.can_afford(cost):
		return false
	return true


func begin_place(building_id: String) -> bool:
	if not can_start_place(building_id):
		return false
	placing_id = building_id
	_footprint = BuildingDatabase.footprint_of(building_id)
	_update_ghost_from_mouse()
	placement_started.emit(building_id)
	queue_redraw()
	return true


func cancel_place() -> void:
	if placing_id == "":
		return
	var id := placing_id
	placing_id = ""
	placement_finished.emit(id, false)
	queue_redraw()


func try_place_at(building_id: String, origin: Vector2i, spend: bool = true) -> Node:
	if not BuildingDatabase.meets_prereqs(get_tree(), building_id, GameConstants.Team.PLAYER):
		return null
	var fp := BuildingDatabase.footprint_of(building_id)
	if not _is_valid_placement(origin, fp):
		return null
	var cost := int(BuildingDatabase.get_building(building_id).get("cost", 0))
	var economy := _economy()
	if spend:
		if economy == null or not economy.try_spend(cost):
			return null
	return _spawn_building(building_id, origin, fp)


func _unhandled_input(event: InputEvent) -> void:
	if placing_id == "":
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_place()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_update_ghost_from_mouse()
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_place()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if _try_confirm_place():
				get_viewport().set_input_as_handled()


func _try_confirm_place() -> bool:
	if placing_id == "" or not _ghost_valid:
		return false
	var id := placing_id
	var b := try_place_at(id, _ghost_origin, true)
	if b == null:
		return false
	placing_id = ""
	placement_finished.emit(id, true)
	queue_redraw()
	return true


func _update_ghost_from_mouse() -> void:
	var map := _world_map()
	if map == null:
		_ghost_valid = false
		return
	var cell: Vector2i = map.world_to_cell(get_global_mouse_position())
	_ghost_origin = Vector2i(
		cell.x - int(_footprint.x / 2),
		cell.y - int(_footprint.y / 2)
	)
	_ghost_valid = _is_valid_placement(_ghost_origin, _footprint)


func _is_valid_placement(origin: Vector2i, fp: Vector2i) -> bool:
	var map := _world_map()
	if map == null or not map.can_place_footprint(origin, fp):
		return false
	var ts := GameConstants.TILE_SIZE
	var rect := Rect2(
		Vector2(origin.x * ts, origin.y * ts),
		Vector2(fp.x * ts, fp.y * ts)
	)
	var root := _buildings_root()
	if root == null:
		return true
	for child in root.get_children():
		if child.has_method("get_selection_rect") and rect.intersects(child.get_selection_rect()):
			return false
	return true


func _spawn_building(building_id: String, origin: Vector2i, fp: Vector2i) -> Node:
	var root := _buildings_root()
	if root == null:
		return null
	var scene := preload("res://scenes/building.tscn")
	var b: StaticBody2D = scene.instantiate()
	b.building_id = building_id
	b.footprint = fp
	b.team = GameConstants.Team.PLAYER
	b.global_position = Vector2(
		origin.x * GameConstants.TILE_SIZE,
		origin.y * GameConstants.TILE_SIZE
	)
	var def := BuildingDatabase.get_building(building_id)
	var c: Variant = def.get("color", null)
	if typeof(c) == TYPE_ARRAY and c.size() >= 3:
		b.team_color = Color(float(c[0]), float(c[1]), float(c[2]))
	root.add_child(b)
	var power := get_node_or_null(power_grid_path)
	if power and power.has_method("register_building"):
		power.register_building(b)
	elif power and power.has_method("recalculate"):
		power.recalculate()
	building_placed.emit(b)
	var economy := _economy()
	if economy and economy.has_method("recalculate_cap"):
		economy.recalculate_cap()
	return b


func _world_map() -> Node2D:
	return get_node_or_null(world_map_path) as Node2D


func _buildings_root() -> Node2D:
	return get_node_or_null(buildings_root_path) as Node2D


func _economy() -> Node:
	return get_node_or_null(economy_path)


func _draw() -> void:
	if placing_id == "":
		return
	var ts := GameConstants.TILE_SIZE
	var rect := Rect2(
		Vector2(_ghost_origin.x * ts, _ghost_origin.y * ts),
		Vector2(_footprint.x * ts, _footprint.y * ts)
	)
	var fill := Color(0.2, 0.9, 0.35, 0.35) if _ghost_valid else Color(0.9, 0.2, 0.2, 0.35)
	var edge := Color(0.3, 1.0, 0.4, 0.95) if _ghost_valid else Color(1.0, 0.3, 0.3, 0.95)
	draw_rect(rect, fill, true)
	draw_rect(rect, edge, false, 2.0)
