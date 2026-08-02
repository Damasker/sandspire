extends Node2D
## Draws unexplored (black) and explored-but-not-visible (dim) fog cells.

@export var vision_path: NodePath

var _vision: Node


func _ready() -> void:
	z_index = 40
	_vision = get_node_or_null(vision_path)
	if _vision and _vision.has_signal("vision_updated"):
		_vision.vision_updated.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if _vision == null:
		_vision = get_node_or_null(vision_path)
	if _vision == null:
		return
	var ts := GameConstants.TILE_SIZE
	for y in GameConstants.MAP_HEIGHT:
		for x in GameConstants.MAP_WIDTH:
			var cell := Vector2i(x, y)
			var sight: int = int(_vision.get_cell_sight(cell))
			if sight == 2:  # VISIBLE
				continue
			var col: Color = Color(0.02, 0.02, 0.05, 0.55) if sight == 1 else Color(0.0, 0.0, 0.0, 0.92)
			draw_rect(Rect2(x * ts, y * ts, ts, ts), col, true)
