extends Control
## Terrain + friendlies + visible enemies. Click jumps camera.

@export var world_map_path: NodePath
@export var vision_path: NodePath
@export var camera_path: NodePath
@export var units_root_path: NodePath
@export var buildings_root_path: NodePath

const MAP_W := 180.0
const MAP_H := 135.0

var _world_map: Node2D
var _vision: Node
var _camera: Camera2D


func _ready() -> void:
	custom_minimum_size = Vector2(MAP_W, MAP_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_world_map = get_node_or_null(world_map_path) as Node2D
	_vision = get_node_or_null(vision_path)
	_camera = get_node_or_null(camera_path) as Camera2D
	if _vision and _vision.has_signal("vision_updated"):
		_vision.vision_updated.connect(queue_redraw)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		var local: Vector2 = mb.position
		var world: Vector2 = _minimap_to_world(local)
		if _camera and _camera.has_method("jump_to"):
			_camera.jump_to(world)
		elif _camera:
			_camera.global_position = world
		accept_event()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.08, 0.1, 0.9), true)
	if _world_map == null:
		return
	var sx := size.x / float(GameConstants.MAP_WIDTH)
	var sy := size.y / float(GameConstants.MAP_HEIGHT)
	for y in GameConstants.MAP_HEIGHT:
		for x in GameConstants.MAP_WIDTH:
			var cell := Vector2i(x, y)
			var sight := 2
			if _vision:
				sight = int(_vision.get_cell_sight(cell))
			var col: Color = GameConstants.TERRAIN_COLORS.get(
				_world_map.get_terrain_at(cell), Color(0.5, 0.4, 0.3)
			)
			if sight == 0:
				col = Color(0.02, 0.02, 0.03)
			elif sight == 1:
				col = col.darkened(0.55)
			draw_rect(Rect2(x * sx, y * sy, sx + 0.5, sy + 0.5), col, true)

	_draw_entities(true)
	_draw_entities(false)

	# Camera frame
	if _camera:
		var half := get_viewport().get_visible_rect().size * 0.5 / _camera.zoom.x
		var tl := _world_to_minimap(_camera.global_position - half)
		var br := _world_to_minimap(_camera.global_position + half)
		draw_rect(Rect2(tl, br - tl), Color(1, 1, 1, 0.85), false, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.7, 0.7, 0.75, 0.8), false, 1.0)


func _draw_entities(friendly: bool) -> void:
	var roots: Array = []
	var uroot := get_node_or_null(units_root_path)
	var broot := get_node_or_null(buildings_root_path)
	if uroot:
		roots.append_array(uroot.get_children())
	if broot:
		roots.append_array(broot.get_children())
	for node in roots:
		if not is_instance_valid(node):
			continue
		var is_player := int(node.get("team")) == GameConstants.Team.PLAYER
		if friendly != is_player:
			continue
		if not is_player:
			if _vision and not _vision.is_world_visible(_entity_pos(node)):
				continue
			if not node.visible:
				continue
		var p := _world_to_minimap(_entity_pos(node))
		var col := Color(0.3, 0.75, 1.0) if is_player else Color(1.0, 0.3, 0.25)
		draw_circle(p, 2.2, col)


func _entity_pos(node: Node) -> Vector2:
	if node.has_method("get_selection_rect"):
		return node.get_selection_rect().get_center()
	return node.global_position


func _world_to_minimap(world: Vector2) -> Vector2:
	var map_px := Vector2(
		GameConstants.MAP_WIDTH * GameConstants.TILE_SIZE,
		GameConstants.MAP_HEIGHT * GameConstants.TILE_SIZE
	)
	return Vector2(world.x / map_px.x * size.x, world.y / map_px.y * size.y)


func _minimap_to_world(local: Vector2) -> Vector2:
	var map_px := Vector2(
		GameConstants.MAP_WIDTH * GameConstants.TILE_SIZE,
		GameConstants.MAP_HEIGHT * GameConstants.TILE_SIZE
	)
	return Vector2(local.x / size.x * map_px.x, local.y / size.y * map_px.y)
