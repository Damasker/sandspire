extends Node2D
## Box select + RMB move/attack; A+LMB attack-move; S stop; H hold; group slots.

signal selection_updated(count: int)
signal selection_changed(units: Array, buildings: Array)

@export var units_root_path: NodePath
@export var buildings_root_path: NodePath
@export var camera_path: NodePath
@export var build_controller_path: NodePath
@export var vision_path: NodePath

const SLOT_SPACING := 30.0

var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _drag_current: Vector2 = Vector2.ZERO
var _selected_units: Array[Node] = []
var _selected_buildings: Array[Node] = []
var _vision: Node
var _attack_move_armed: bool = false


func _ready() -> void:
	z_index = 100
	_vision = get_node_or_null(vision_path)


func get_selected_buildings() -> Array:
	return _selected_buildings.duplicate()


func get_selected_units() -> Array:
	return _selected_units.duplicate()


func _unhandled_input(event: InputEvent) -> void:
	var bc := get_node_or_null(build_controller_path)
	if bc and bc.has_method("is_placing") and bc.is_placing():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_A:
			_attack_move_armed = true
			get_viewport().set_input_as_handled()
			return
		if key.keycode == KEY_S:
			_issue_stop()
			get_viewport().set_input_as_handled()
			return
		if key.keycode == KEY_H:
			_issue_hold()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var world := get_global_mouse_position()
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_start = world
				_drag_current = world
				queue_redraw()
			else:
				if _dragging:
					_dragging = false
					var tiny := Rect2(_drag_start, _drag_current - _drag_start).abs().size.length() < 6.0
					var want_amove := _attack_move_armed or Input.is_key_pressed(KEY_A)
					if tiny and want_amove and not _selected_units.is_empty():
						_attack_move_armed = false
						_issue_group_move(_drag_start, true)
					else:
						_attack_move_armed = false
						_finish_select(not Input.is_key_pressed(KEY_SHIFT))
					queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_attack_move_armed = false
			_issue_command(world)
	elif event is InputEventMouseMotion and _dragging:
		_drag_current = get_global_mouse_position()
		queue_redraw()


func _finish_select(clear_previous: bool) -> void:
	if clear_previous:
		_clear_selection()
	var rect := Rect2(_drag_start, _drag_current - _drag_start).abs()
	if rect.size.length() < 6.0:
		var hit_unit := _pick_unit_at(_drag_start, true)
		if hit_unit:
			_add_unit(hit_unit)
		else:
			var hit_b := _pick_building_at(_drag_start, true)
			if hit_b:
				_add_building(hit_b)
	else:
		for unit in _iter_units():
			if _is_player(unit) and rect.intersects(unit.get_selection_rect()):
				_add_unit(unit)
		for b in _iter_buildings():
			if _is_player(b) and b.has_method("get_selection_rect") and rect.intersects(b.get_selection_rect()):
				_add_building(b)
	_prune_dead_selection()
	_emit_selection()


func _issue_command(world: Vector2) -> void:
	_prune_dead_selection()
	var enemy := _pick_enemy_at(world)
	if enemy:
		for unit in _selected_units:
			if unit.has_method("command_attack"):
				unit.command_attack(enemy)
		return
	_issue_group_move(world, false)


func _issue_group_move(world: Vector2, attack_move: bool) -> void:
	_prune_dead_selection()
	var n := _selected_units.size()
	if n == 0:
		return
	var slots := _slot_offsets(n)
	for i in n:
		var unit: Node = _selected_units[i]
		var dest: Vector2 = world + slots[i]
		if attack_move and unit.has_method("command_attack_move"):
			unit.command_attack_move(dest)
		elif unit.has_method("command_move"):
			unit.command_move(dest)


func _issue_stop() -> void:
	_prune_dead_selection()
	_attack_move_armed = false
	for unit in _selected_units:
		if unit.has_method("command_stop"):
			unit.command_stop()


func _issue_hold() -> void:
	_prune_dead_selection()
	_attack_move_armed = false
	for unit in _selected_units:
		if unit.has_method("command_hold"):
			unit.command_hold()


func _slot_offsets(count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if count <= 1:
		out.append(Vector2.ZERO)
		return out
	var cols := maxi(1, int(ceili(sqrt(float(count)))))
	var rows := maxi(1, int(ceili(float(count) / float(cols))))
	for i in count:
		var col := i % cols
		var row := int(i / cols)
		out.append(Vector2(
			(float(col) - float(cols - 1) * 0.5) * SLOT_SPACING,
			(float(row) - float(rows - 1) * 0.5) * SLOT_SPACING
		))
	return out


func _pick_enemy_at(world: Vector2) -> Node:
	var best: Node = null
	var best_d := 28.0
	for unit in _iter_units():
		if _is_player(unit):
			continue
		if not _is_revealed(unit):
			continue
		var d: float = unit.global_position.distance_to(world)
		if d < best_d:
			best_d = d
			best = unit
	for b in _iter_buildings():
		if _is_player(b):
			continue
		if not _is_revealed(b):
			continue
		if b.has_method("get_selection_rect") and b.get_selection_rect().has_point(world):
			return b
	return best


func _is_revealed(node: Node) -> bool:
	if _vision == null:
		_vision = get_node_or_null(vision_path)
	if _vision == null:
		return true
	var pos: Vector2 = node.global_position
	if node.has_method("get_selection_rect"):
		pos = node.get_selection_rect().get_center()
	return bool(_vision.is_world_visible(pos))


func _pick_unit_at(world: Vector2, player_only: bool) -> Node:
	var best: Node = null
	var best_d := 18.0
	for unit in _iter_units():
		if player_only and not _is_player(unit):
			continue
		var d: float = unit.global_position.distance_to(world)
		if d < best_d:
			best_d = d
			best = unit
	return best


func _pick_building_at(world: Vector2, player_only: bool) -> Node:
	for b in _iter_buildings():
		if player_only and not _is_player(b):
			continue
		if b.has_method("get_selection_rect") and b.get_selection_rect().has_point(world):
			return b
	return null


func _is_player(node: Node) -> bool:
	return int(node.get("team")) == GameConstants.Team.PLAYER


func _clear_selection() -> void:
	for unit in _selected_units:
		if is_instance_valid(unit) and unit.has_method("set_selected"):
			unit.set_selected(false)
	for b in _selected_buildings:
		if is_instance_valid(b) and b.has_method("set_selected"):
			b.set_selected(false)
	_selected_units.clear()
	_selected_buildings.clear()


func _add_unit(unit: Node) -> void:
	if unit in _selected_units:
		return
	_selected_units.append(unit)
	if unit.has_method("set_selected"):
		unit.set_selected(true)


func _add_building(b: Node) -> void:
	if b in _selected_buildings:
		return
	_selected_buildings.append(b)
	if b.has_method("set_selected"):
		b.set_selected(true)


func _prune_dead_selection() -> void:
	_selected_units = _selected_units.filter(func(u): return is_instance_valid(u))
	_selected_buildings = _selected_buildings.filter(func(b): return is_instance_valid(b))


func _emit_selection() -> void:
	var count := _selected_units.size() + _selected_buildings.size()
	selection_updated.emit(count)
	selection_changed.emit(_selected_units.duplicate(), _selected_buildings.duplicate())


func _iter_units() -> Array:
	var root := get_node_or_null(units_root_path)
	if root == null:
		return get_tree().get_nodes_in_group("units")
	return root.get_children()


func _iter_buildings() -> Array:
	var root := get_node_or_null(buildings_root_path)
	if root == null:
		return get_tree().get_nodes_in_group("buildings")
	return root.get_children()


func _draw() -> void:
	if not _dragging:
		return
	var rect := Rect2(_drag_start, _drag_current - _drag_start).abs()
	draw_rect(rect, Color(0.3, 1.0, 0.4, 0.12), true)
	draw_rect(rect, Color(0.4, 1.0, 0.5, 0.9), false, 1.5)
