extends Node
## Grid A* over walkable cells. Buildings (and temp blocks) are obstacles.

signal grid_rebuilt

var _blocked: PackedByteArray = PackedByteArray()
var _temp_blocked: PackedByteArray = PackedByteArray()
var _world_map: Node2D
var _buildings_root: Node2D


func _ready() -> void:
	var n := GameConstants.MAP_WIDTH * GameConstants.MAP_HEIGHT
	_blocked.resize(n)
	_temp_blocked.resize(n)
	_blocked.fill(0)
	_temp_blocked.fill(0)
	call_deferred("_bind_and_rebuild")


func _bind_and_rebuild() -> void:
	var main := get_tree().current_scene
	if main:
		_world_map = main.get_node_or_null("WorldMap")
		_buildings_root = main.get_node_or_null("Buildings")
		var bc := main.get_node_or_null("BuildController")
		if bc and bc.has_signal("building_placed") and not bc.building_placed.is_connected(_on_building_placed):
			bc.building_placed.connect(_on_building_placed)
	rebuild_blocked()


func _on_building_placed(building: Node) -> void:
	if building and building.has_signal("died") and not building.died.is_connected(_on_building_died):
		building.died.connect(_on_building_died)
	rebuild_blocked()


func _on_building_died(_building: Node) -> void:
	call_deferred("rebuild_blocked")


func rebuild_blocked() -> void:
	_blocked.fill(0)
	if _buildings_root == null:
		var main := get_tree().current_scene
		if main:
			_buildings_root = main.get_node_or_null("Buildings")
			_world_map = main.get_node_or_null("WorldMap")
	if _buildings_root == null or _world_map == null:
		grid_rebuilt.emit()
		return
	for b in _buildings_root.get_children():
		if not is_instance_valid(b) or b.get("alive") == false:
			continue
		if b.has_signal("died") and not b.died.is_connected(_on_building_died):
			b.died.connect(_on_building_died)
		var fp: Vector2i = b.get("footprint") if b.get("footprint") != null else Vector2i(2, 2)
		# Buildings are placed at top-left of footprint in world pixels
		var origin := Vector2i(
			int(b.global_position.x) / GameConstants.TILE_SIZE,
			int(b.global_position.y) / GameConstants.TILE_SIZE
		)
		for y in fp.y:
			for x in fp.x:
				var cell := Vector2i(origin.x + x, origin.y + y)
				if _in_bounds(cell):
					_blocked[_idx(cell)] = 1
	grid_rebuilt.emit()


func set_temp_blocked_rect(origin: Vector2i, size: Vector2i, blocked: bool = true) -> void:
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(origin.x + x, origin.y + y)
			if _in_bounds(cell):
				_temp_blocked[_idx(cell)] = 1 if blocked else 0


func clear_temp_blocked() -> void:
	_temp_blocked.fill(0)


func is_walkable(cell: Vector2i) -> bool:
	if not _in_bounds(cell):
		return false
	var i := _idx(cell)
	return _blocked[i] == 0 and _temp_blocked[i] == 0


func find_path(from_world: Vector2, to_world: Vector2) -> PackedVector2Array:
	if _world_map == null:
		_bind_and_rebuild()
	if _world_map == null:
		return PackedVector2Array([to_world])

	var start: Vector2i = _world_map.world_to_cell(from_world)
	var goal: Vector2i = _world_map.world_to_cell(to_world)
	goal = _nearest_walkable(goal)
	start = _nearest_walkable(start)
	if start == goal:
		return PackedVector2Array([_world_map.cell_to_world_center(goal)])

	var came := {}  # int idx -> int parent idx
	var gscore := {}
	var open: Array[Vector2i] = [start]
	var start_i := _idx(start)
	gscore[start_i] = 0.0

	var dirs := [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]

	var found := false
	var guard := 0
	while not open.is_empty() and guard < 8000:
		guard += 1
		var best_i := 0
		var best_f := INF
		for i in open.size():
			var c: Vector2i = open[i]
			var ci := _idx(c)
			var f: float = float(gscore.get(ci, INF)) + _heuristic(c, goal)
			if f < best_f:
				best_f = f
				best_i = i
		var current: Vector2i = open[best_i]
		open.remove_at(best_i)
		if current == goal:
			found = true
			break
		var cur_i := _idx(current)
		var cur_g: float = float(gscore.get(cur_i, INF))
		for d in dirs:
			var nxt: Vector2i = current + d
			if not is_walkable(nxt):
				continue
			# No corner-cutting through blocked diagonals
			if d.x != 0 and d.y != 0:
				if not is_walkable(Vector2i(current.x + d.x, current.y)) \
					or not is_walkable(Vector2i(current.x, current.y + d.y)):
					continue
			var step: float = 1.414 if d.x != 0 and d.y != 0 else 1.0
			var ni := _idx(nxt)
			var tentative: float = cur_g + step
			if tentative < float(gscore.get(ni, INF)):
				came[ni] = cur_i
				gscore[ni] = tentative
				if not open.has(nxt):
					open.append(nxt)

	var out := PackedVector2Array()
	if not found:
		out.append(to_world)
		return out

	# Reconstruct
	var chain: Array[Vector2i] = []
	var walk := goal
	var safety := 0
	while _idx(walk) != start_i and safety < 5000:
		safety += 1
		chain.append(walk)
		var pi: int = int(came.get(_idx(walk), start_i))
		walk = Vector2i(pi % GameConstants.MAP_WIDTH, int(pi / GameConstants.MAP_WIDTH))
	chain.reverse()
	for cell in chain:
		out.append(_world_map.cell_to_world_center(cell))
	if out.is_empty():
		out.append(to_world)
	return out


func _nearest_walkable(cell: Vector2i) -> Vector2i:
	if is_walkable(cell):
		return cell
	for r in range(1, 8):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := Vector2i(cell.x + dx, cell.y + dy)
				if is_walkable(c):
					return c
	return cell


func _heuristic(a: Vector2i, b: Vector2i) -> float:
	var dx := absf(float(a.x - b.x))
	var dy := absf(float(a.y - b.y))
	return maxf(dx, dy) + 0.414 * minf(dx, dy)


func _idx(cell: Vector2i) -> int:
	return cell.y * GameConstants.MAP_WIDTH + cell.x


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GameConstants.MAP_WIDTH and cell.y < GameConstants.MAP_HEIGHT
