extends Camera2D
## WASD / arrows pan, wheel zoom, optional edge scroll.

@export var pan_speed: float = 600.0
@export var edge_scroll_margin: float = 24.0
@export var edge_scroll_enabled: bool = true
@export var zoom_min: float = 0.4
@export var zoom_max: float = 2.0
@export var zoom_step: float = 0.1

var _bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(1024, 768))


func configure_bounds(map_size: Vector2) -> void:
	_bounds = Rect2(Vector2.ZERO, map_size)
	_clamp_position()


func jump_to(world_pos: Vector2) -> void:
	global_position = world_pos
	_clamp_position()


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0

	if edge_scroll_enabled and get_window().has_focus():
		var mouse := get_viewport().get_mouse_position()
		var vr := get_viewport().get_visible_rect().size
		if mouse.x <= edge_scroll_margin:
			dir.x -= 1.0
		elif mouse.x >= vr.x - edge_scroll_margin:
			dir.x += 1.0
		if mouse.y <= edge_scroll_margin:
			dir.y -= 1.0
		elif mouse.y >= vr.y - edge_scroll_margin:
			dir.y += 1.0

	if dir != Vector2.ZERO:
		global_position += dir.normalized() * pan_speed * delta / zoom.x
		_clamp_position()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(zoom.x + zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(zoom.x - zoom_step)


func _set_zoom(value: float) -> void:
	var z := clampf(value, zoom_min, zoom_max)
	zoom = Vector2(z, z)
	_clamp_position()


func _clamp_position() -> void:
	var half := get_viewport_rect().size * 0.5 / zoom.x
	global_position.x = clampf(global_position.x, _bounds.position.x + half.x, _bounds.end.x - half.x)
	global_position.y = clampf(global_position.y, _bounds.position.y + half.y, _bounds.end.y - half.y)
