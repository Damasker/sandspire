extends Node
## Per-team power: Windtrap produces, buildings consume. Surplus < 0 pauses production.

signal power_changed(produced: int, consumed: int, surplus: int)

@export var team: int = GameConstants.Team.PLAYER

var produced: int = 0
var consumed: int = 0
var surplus: int = 0

## When surplus < 0, producers tick at this rate (0 = paused).
const LOW_POWER_RATE := 0.0


func _ready() -> void:
	call_deferred("recalculate")


func recalculate() -> void:
	var prod := 0
	var cons := 0
	var group_name := "team_player" if team == GameConstants.Team.PLAYER else "team_enemy"
	for b in get_tree().get_nodes_in_group(group_name):
		if not b.is_in_group("buildings"):
			continue
		if b.get("alive") == false:
			continue
		var def := BuildingDatabase.get_building(str(b.get("building_id")))
		var p := int(def.get("power", 0))
		if p > 0:
			prod += p
		elif p < 0:
			cons += -p
	produced = prod
	consumed = cons
	surplus = prod - cons
	power_changed.emit(produced, consumed, surplus)


func is_low_power() -> bool:
	return surplus < 0


func get_production_rate() -> float:
	if surplus < 0:
		return LOW_POWER_RATE
	return 1.0


func register_building(building: Node) -> void:
	if building and int(building.get("team")) != team:
		return
	if building.has_signal("died") and not building.died.is_connected(_on_building_died):
		building.died.connect(_on_building_died)
	recalculate()


func _on_building_died(_b: Node) -> void:
	call_deferred("recalculate")
