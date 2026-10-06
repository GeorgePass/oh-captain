class_name Oxygen
extends Node
## The clock that gives a dive an end.
##
## It is deliberately a node on the run rather than a property of the hull: the
## tank empties whether or not anything is happening to the boat, and it has to
## keep emptying while the sonar is sweeping and the fish are ignoring you.
##
## Nothing here checks for the harbour, because it does not have to. Docking
## pauses the tree, a paused tree does not process this node, and so being
## alongside freezes the tank for free — the rule is enforced by the pause
## rather than by a test that could be forgotten.

signal oxygen_changed(current: float, max_oxygen: float)
## Raised when the tank hits empty, and again when it is topped up. The HUD
## listens for this rather than inferring drowning from a zero reading, so the
## alarm does not fire every frame for as long as you last.
signal drowning_changed(drowning: bool)

@onready var player: Player = get_node_or_null("../World/Player") as Player

## Full-tank capacity, grown by the refit bay. Defaults to the config number.
var max_oxygen := GameConfig.OXYGEN_MAX
var current := GameConfig.OXYGEN_MAX
var _drowning := false


func _ready() -> void:
	oxygen_changed.emit(current, max_oxygen)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.hp <= 0:
		return
	if current <= 0.0:
		# Past empty this stops being a timer and starts being damage. The hull
		# is not asked for permission and nothing plays: drowning arrives quietly
		# and keeps arriving, which is what makes it worth swimming home for.
		player.drown(GameConfig.OXYGEN_DROWN_DPS * delta)
		return
	current = maxf(current - GameConfig.OXYGEN_DRAIN * delta, 0.0)
	oxygen_changed.emit(current, max_oxygen)
	if current <= 0.0:
		_drowning = true
		drowning_changed.emit(true)


## Alongside is the only place the tanks can be filled, which is what makes the
## harbour worth the swim back rather than a convenience stop.
func refill() -> void:
	current = max_oxygen
	oxygen_changed.emit(current, max_oxygen)
	if _drowning:
		_drowning = false
		drowning_changed.emit(false)


## A bigger tank, delivered partly topped up. The refit bay sells seconds of
## capacity; the air in the new section is there the moment it is fitted.
func expand_tank(capacity: float) -> void:
	if capacity <= max_oxygen:
		return
	var gained := capacity - max_oxygen
	max_oxygen = capacity
	current = mini(current + gained, max_oxygen)
	oxygen_changed.emit(current, max_oxygen)
