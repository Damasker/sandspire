extends Node
## Lightweight army value / unit counts for HUD debug.

signal stats_updated(player_count: int, player_value: int, enemy_count: int, enemy_value: int)

@export var update_interval: float = 0.5

var player_count: int = 0
var player_value: int = 0
var enemy_count: int = 0
var enemy_value: int = 0

var _accum: float = 0.0


func _process(delta: float) -> void:
	_accum += delta
	if _accum < update_interval:
		return
	_accum = 0.0
	refresh()


func refresh() -> void:
	var pc := 0
	var pv := 0
	var ec := 0
	var ev := 0
	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u) or u.get("alive") == false:
			continue
		if u.is_in_group("harvesters") or str(u.get("unit_id")).contains("harvester"):
			continue
		if float(u.get("dps")) <= 0.0:
			continue
		var uid := str(u.get("unit_id"))
		var cost := int(UnitDatabase.get_unit(uid).get("cost", 0))
		if int(u.get("team")) == GameConstants.Team.PLAYER:
			pc += 1
			pv += cost
		elif int(u.get("team")) == GameConstants.Team.ENEMY:
			ec += 1
			ev += cost
	player_count = pc
	player_value = pv
	enemy_count = ec
	enemy_value = ev
	stats_updated.emit(pc, pv, ec, ev)


static func army_value_for_team(tree: SceneTree, team: int) -> Dictionary:
	var count := 0
	var value := 0
	for u in tree.get_nodes_in_group("units"):
		if not is_instance_valid(u) or u.get("alive") == false:
			continue
		if int(u.get("team")) != team:
			continue
		if u.is_in_group("harvesters") or str(u.get("unit_id")).contains("harvester"):
			continue
		if float(u.get("dps")) <= 0.0:
			continue
		count += 1
		value += int(UnitDatabase.get_unit(str(u.get("unit_id"))).get("cost", 0))
	return {"count": count, "value": value}
