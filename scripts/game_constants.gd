class_name GameConstants
extends Object

const TILE_SIZE := 32
const MAP_WIDTH := 48
const MAP_HEIGHT := 36

enum Terrain { SAND, ROCK, SPICE, BLOOM }
enum Team { PLAYER, ENEMY }

const TERRAIN_COLORS := {
	Terrain.SAND: Color(0.76, 0.62, 0.35),
	Terrain.ROCK: Color(0.42, 0.38, 0.34),
	Terrain.SPICE: Color(0.55, 0.28, 0.72),
	Terrain.BLOOM: Color(0.75, 0.45, 0.9),
}

const ARMOR_VALUE := {
	"none": 0.0,
	"light": 0.0,
	"medium": 3.0,
	"heavy": 6.0,
}

const RANGE_PX := {
	"none": 0.0,
	"short": 90.0,
	"med": 150.0,
	"long": 220.0,
}


static func armor_value(armor_name: String) -> float:
	return float(ARMOR_VALUE.get(armor_name, 0.0))


static func range_px(range_name: String) -> float:
	return float(RANGE_PX.get(range_name, 120.0))
