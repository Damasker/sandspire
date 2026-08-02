extends Node
## Shared player vision on a cell grid. Explored sticky; visible recomputed.

signal vision_updated

enum CellSight { HIDDEN = 0, EXPLORED = 1, VISIBLE = 2 }

var explored: PackedByteArray = PackedByteArray()
var visible: PackedByteArray = PackedByteArray()

var _world_map: Node2D
var _accum: float = 0.0
const UPDATE_INTERVAL := 0.12


func _ready() -> void:
	var n := GameConstants.MAP_WIDTH * GameConstants.MAP_HEIGHT
	explored.resize(n)
	visible.resize(n)
	explored.fill(0)
	visible.fill(0)
	call_deferred("_bind_and_update")


func _bind_and_update() -> void:
	var main := get_tree().current_scene
	if main:
		_world_map = main.get_node_or_null("WorldMap")
	update_vision()


func _process(delta: float) -> void:
	_accum += delta
	if _accum >= UPDATE_INTERVAL:
		_accum = 0.0
		update_vision()


func update_vision() -> void:
	visible.fill(0)
	for node in get_tree().get_nodes_in_group("team_player"):
		if not is_instance_valid(node):
			continue
		if node.get("alive") == false:
			continue
		var tiles := _vision_tiles_of(node)
		if tiles <= 0:
			continue
		var center := _vision_center_cell(node)
		_stamp_circle(center, tiles)
	_apply_enemy_visibility()
	vision_updated.emit()


func is_cell_visible(cell: Vector2i) -> bool:
	if not _in_bounds(cell):
		return false
	return visible[_idx(cell)] != 0


func is_cell_explored(cell: Vector2i) -> bool:
	if not _in_bounds(cell):
		return false
	return explored[_idx(cell)] != 0


func is_world_visible(world: Vector2) -> bool:
	if _world_map == null:
		var main := get_tree().current_scene
		if main:
			_world_map = main.get_node_or_null("WorldMap")
	if _world_map == null:
		return true
	return is_cell_visible(_world_map.world_to_cell(world))


func get_cell_sight(cell: Vector2i) -> int:
	if not _in_bounds(cell):
		return CellSight.HIDDEN
	if visible[_idx(cell)] != 0:
		return CellSight.VISIBLE
	if explored[_idx(cell)] != 0:
		return CellSight.EXPLORED
	return CellSight.HIDDEN


## Force-reveal a circle (tests / radar pulse).
func reveal_at_world(world: Vector2, tiles: int) -> void:
	if _world_map == null:
		return
	_stamp_circle(_world_map.world_to_cell(world), tiles)
	_apply_enemy_visibility()
	vision_updated.emit()


func _stamp_circle(center: Vector2i, radius_tiles: int) -> void:
	var r2 := radius_tiles * radius_tiles
	for dy in range(-radius_tiles, radius_tiles + 1):
		for dx in range(-radius_tiles, radius_tiles + 1):
			if dx * dx + dy * dy > r2:
				continue
			var cell := Vector2i(center.x + dx, center.y + dy)
			if not _in_bounds(cell):
				continue
			var i := _idx(cell)
			visible[i] = 1
			explored[i] = 1


func _vision_tiles_of(node: Node) -> int:
	if "vision_tiles" in node:
		return int(node.vision_tiles)
	return 4


func _vision_center_cell(node: Node) -> Vector2i:
	if _world_map == null:
		return Vector2i.ZERO
	if node.has_method("get_selection_rect"):
		var r: Rect2 = node.get_selection_rect()
		return _world_map.world_to_cell(r.get_center())
	return _world_map.world_to_cell(node.global_position)


func _apply_enemy_visibility() -> void:
	for node in get_tree().get_nodes_in_group("team_enemy"):
		if not is_instance_valid(node):
			continue
		var world: Vector2
		if node.has_method("get_selection_rect"):
			world = node.get_selection_rect().get_center()
		else:
			world = node.global_position
		var seen := is_world_visible(world)
		node.visible = seen
		if node is CanvasItem:
			(node as CanvasItem).visible = seen


func _idx(cell: Vector2i) -> int:
	return cell.y * GameConstants.MAP_WIDTH + cell.x


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GameConstants.MAP_WIDTH and cell.y < GameConstants.MAP_HEIGHT
