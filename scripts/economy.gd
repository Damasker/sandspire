extends Node
## Team credits ledger (player Economy / enemy EnemyEconomy).

signal credits_changed(credits: int)

@export var team: int = GameConstants.Team.PLAYER

## Soft cap; each Spice Silo adds credit_bonus (500). High enough for skirmish openers.
const BASE_CREDIT_CAP := 5000

var credits: int = 0
var credit_cap: int = BASE_CREDIT_CAP
## Cumulative credits gained (harvest + grants); used by harvest objectives.
var lifetime_earned: int = 0


func recalculate_cap() -> void:
	var bonus := 0
	if not is_inside_tree():
		credit_cap = BASE_CREDIT_CAP
		return
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b) or b.get("alive") == false:
			continue
		if int(b.get("team")) != team:
			continue
		if str(b.get("building_id")) != "b_silo":
			continue
		var def := BuildingDatabase.get_building("b_silo")
		bonus += int(def.get("credit_bonus", 500))
	credit_cap = BASE_CREDIT_CAP + bonus


func add_credits(amount: int) -> void:
	if amount <= 0:
		return
	recalculate_cap()
	var before := credits
	credits = mini(credits + amount, credit_cap)
	lifetime_earned += credits - before
	credits_changed.emit(credits)


func can_afford(cost: int) -> bool:
	return credits >= cost


func try_spend(cost: int) -> bool:
	if cost < 0 or credits < cost:
		return false
	credits -= cost
	credits_changed.emit(credits)
	return true
