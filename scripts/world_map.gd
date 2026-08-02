extends Node2D
## Procedural desert map with depletable spice cells + light bloom refresh.

signal map_ready(size_px: Vector2)
signal spice_changed(cell: Vector2i, remaining: int)

const SPICE_AMOUNT_DEFAULT := 200
const BLOOM_AMOUNT_DEFAULT := 500
const BLOOM_REFRESH_INTERVAL := 45.0

## Mission/skirmish may set these before _ready (S14 / lobby).
var map_seed: int = 11042
## "ridge" (classic) or "canyon" (map 2).
var map_layout: String = "ridge"

var _terrain: PackedByteArray = PackedByteArray()
var _spice: PackedInt32Array = PackedInt32Array()
var _bloom_cells: Array[Vector2i] = []
var _bloom_cd: float = 0.0


func _ready() -> void:
	_generate()
	queue_redraw()
	map_ready.emit(map_size_px())


func _process(delta: float) -> void:
	_bloom_cd += delta
	if _bloom_cd >= BLOOM_REFRESH_INTERVAL:
		_bloom_cd = 0.0
		_refresh_blooms()


func map_size_px() -> Vector2:
	return Vector2(
		GameConstants.MAP_WIDTH * GameConstants.TILE_SIZE,
		GameConstants.MAP_HEIGHT * GameConstants.TILE_SIZE
	)


func world_to_cell(world: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(world.x) / GameConstants.TILE_SIZE, 0, GameConstants.MAP_WIDTH - 1),
		clampi(int(world.y) / GameConstants.TILE_SIZE, 0, GameConstants.MAP_HEIGHT - 1)
	)


func cell_to_world_center(cell: Vector2i) -> Vector2:
	var ts := GameConstants.TILE_SIZE
	return Vector2(cell.x * ts + ts * 0.5, cell.y * ts + ts * 0.5)


func get_terrain_at(cell: Vector2i) -> int:
	if not _in_bounds(cell):
		return GameConstants.Terrain.SAND
	return int(_terrain[cell.y * GameConstants.MAP_WIDTH + cell.x])


func get_spice_at(cell: Vector2i) -> int:
	if not _in_bounds(cell):
		return 0
	return int(_spice[cell.y * GameConstants.MAP_WIDTH + cell.x])


func is_buildable(cell: Vector2i) -> bool:
	return get_terrain_at(cell) == GameConstants.Terrain.ROCK


func is_worm_safe(world: Vector2) -> bool:
	## Rock is safe from the worm; sand/spice/bloom are not.
	return get_terrain_at(world_to_cell(world)) == GameConstants.Terrain.ROCK


func can_place_footprint(origin: Vector2i, footprint: Vector2i) -> bool:
	if footprint.x <= 0 or footprint.y <= 0:
		return false
	for y in footprint.y:
		for x in footprint.x:
			var cell := Vector2i(origin.x + x, origin.y + y)
			if not _in_bounds(cell) or not is_buildable(cell):
				return false
	return true


func harvest_spice(cell: Vector2i, amount: int) -> int:
	if amount <= 0 or not _in_bounds(cell):
		return 0
	var idx := cell.y * GameConstants.MAP_WIDTH + cell.x
	var available: int = int(_spice[idx])
	if available <= 0:
		return 0
	var taken: int = mini(available, amount)
	_spice[idx] = available - taken
	if _spice[idx] <= 0:
		_spice[idx] = 0
		_terrain[idx] = GameConstants.Terrain.SAND
	spice_changed.emit(cell, int(_spice[idx]))
	queue_redraw()
	return taken


func find_nearest_spice_cell(from_world: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in GameConstants.MAP_HEIGHT:
		for x in GameConstants.MAP_WIDTH:
			var idx := y * GameConstants.MAP_WIDTH + x
			if _spice[idx] <= 0:
				continue
			var cell := Vector2i(x, y)
			var d := from_world.distance_squared_to(cell_to_world_center(cell))
			if d < best_d:
				best_d = d
				best = cell
	return best


func total_spice_remaining() -> int:
	var sum := 0
	for v in _spice:
		sum += int(v)
	return sum


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GameConstants.MAP_WIDTH and cell.y < GameConstants.MAP_HEIGHT


func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed if map_seed != 0 else 11042
	var n := GameConstants.MAP_WIDTH * GameConstants.MAP_HEIGHT
	_terrain.resize(n)
	_spice.resize(n)
	_bloom_cells.clear()
	var spice_shift := int(rng.randi_range(-2, 2))
	var layout := map_layout.to_lower()
	for y in GameConstants.MAP_HEIGHT:
		for x in GameConstants.MAP_WIDTH:
			var t := GameConstants.Terrain.SAND
			var spice_amt := 0
			if layout == "canyon":
				# Map 2: west + east shelves, spice river down the middle.
				if x > 6 and x < 20 and y > 11 and y < 27:
					t = GameConstants.Terrain.ROCK
				elif x > 28 and x < 44 and y > 3 and y < 18:
					t = GameConstants.Terrain.ROCK
				elif x > 21 and x < 27 and y > 8 and y < 28:
					t = GameConstants.Terrain.SPICE
					spice_amt = SPICE_AMOUNT_DEFAULT
				elif _in_ellipse(x, y, 24, 18 + spice_shift, 2, 2) and rng.randf() > 0.35:
					t = GameConstants.Terrain.BLOOM
					spice_amt = BLOOM_AMOUNT_DEFAULT
					_bloom_cells.append(Vector2i(x, y))
			else:
				# Ridge (classic)
				if x > 8 and x < 22 and y > 10 and y < 24:
					t = GameConstants.Terrain.ROCK
				elif x > 32 and x < 42 and y > 6 and y < 16:
					t = GameConstants.Terrain.ROCK
				elif _in_ellipse(x, y, 28 + spice_shift, 22, 5, 3):
					t = GameConstants.Terrain.SPICE
					spice_amt = SPICE_AMOUNT_DEFAULT
				elif _in_ellipse(x, y, 38, 28, 4, 3):
					t = GameConstants.Terrain.SPICE
					spice_amt = SPICE_AMOUNT_DEFAULT
				elif _in_ellipse(x, y, 30, 20, 1, 1) and rng.randf() > 0.4:
					t = GameConstants.Terrain.BLOOM
					spice_amt = BLOOM_AMOUNT_DEFAULT
					_bloom_cells.append(Vector2i(x, y))
			var idx := y * GameConstants.MAP_WIDTH + x
			_terrain[idx] = t
			_spice[idx] = spice_amt
	if _bloom_cells.is_empty():
		_bloom_cells.append(Vector2i(24 if layout == "canyon" else 30, 18 if layout == "canyon" else 20))


func _refresh_blooms() -> void:
	## Slow spice return on bloom cells (and a tiny neighbor patch).
	for cell in _bloom_cells:
		if not _in_bounds(cell):
			continue
		var idx := cell.y * GameConstants.MAP_WIDTH + cell.x
		if int(_spice[idx]) < BLOOM_AMOUNT_DEFAULT / 2:
			_spice[idx] = mini(BLOOM_AMOUNT_DEFAULT, int(_spice[idx]) + 80)
			_terrain[idx] = GameConstants.Terrain.BLOOM
			spice_changed.emit(cell, int(_spice[idx]))
		# Soft refill a sand neighbor if empty
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cell + d
			if not _in_bounds(n):
				continue
			var ni := n.y * GameConstants.MAP_WIDTH + n.x
			if int(_terrain[ni]) == GameConstants.Terrain.ROCK:
				continue
			if int(_spice[ni]) <= 0 and randf() < 0.35:
				_spice[ni] = 60
				_terrain[ni] = GameConstants.Terrain.SPICE
				spice_changed.emit(n, 60)
	queue_redraw()


func _in_ellipse(x: int, y: int, cx: int, cy: int, rx: int, ry: int) -> bool:
	var dx := float(x - cx) / float(rx)
	var dy := float(y - cy) / float(ry)
	return dx * dx + dy * dy <= 1.0


func _draw() -> void:
	var ts := GameConstants.TILE_SIZE
	var canyon := str(map_layout) == "canyon"
	for y in GameConstants.MAP_HEIGHT:
		for x in GameConstants.MAP_WIDTH:
			var idx := y * GameConstants.MAP_WIDTH + x
			var t: int = int(_terrain[idx])
			var color: Color = GameConstants.TERRAIN_COLORS[t]
			var spice_amt: int = int(_spice[idx])
			if canyon and t == GameConstants.Terrain.SAND:
				# Cooler floor in the shelf corridor for Ridge/Canyon readability
				color = color.darkened(0.08 + 0.04 * float((x + y) % 3))
			if spice_amt > 0 and (t == GameConstants.Terrain.SPICE or t == GameConstants.Terrain.BLOOM):
				var ratio := clampf(float(spice_amt) / float(SPICE_AMOUNT_DEFAULT), 0.25, 1.0)
				color = color.lightened(ratio * 0.12).darkened((1.0 - ratio) * 0.35)
			# Sand grain noise (deterministic checker dither)
			if t == GameConstants.Terrain.SAND and ((x + y * 3) % 5) == 0:
				color = color.lightened(0.04)
			draw_rect(Rect2(x * ts, y * ts, ts, ts), color, true)
			var ox := x * ts
			var oy := y * ts
			if t == GameConstants.Terrain.ROCK:
				# Hatch + rim so rock shelves read against sand
				draw_line(Vector2(ox + 2, oy + 2), Vector2(ox + ts - 2, oy + ts - 2), Color(0, 0, 0, 0.22), 1.0)
				draw_line(Vector2(ox + ts - 2, oy + 3), Vector2(ox + 3, oy + ts - 2), Color(1, 1, 1, 0.06), 1.0)
				draw_rect(Rect2(ox, oy, ts, ts), Color(0.05, 0.05, 0.06, 0.2), false, 1.0)
			elif t == GameConstants.Terrain.SPICE or t == GameConstants.Terrain.BLOOM:
				# Speckle so spice fields pop at zoom
				draw_circle(Vector2(ox + ts * 0.3, oy + ts * 0.35), 1.6, Color(1.0, 0.85, 0.35, 0.45))
				draw_circle(Vector2(ox + ts * 0.7, oy + ts * 0.65), 1.2, Color(0.95, 0.7, 0.2, 0.35))
				if t == GameConstants.Terrain.BLOOM:
					draw_arc(Vector2(ox + ts * 0.5, oy + ts * 0.5), ts * 0.35, 0, TAU, 10, Color(1, 0.9, 0.4, 0.2), 1.0)
