class_name RefitBay
extends Node
## The harbour refit yard: five permanent buys, one stack of levels each.
##
## "Permanent" means no further than the run: a restart tears the yard down
## with the rest of the world, and the next dive starts with a standard hull.
## Within the run a purchase is the hull now — an expanded tank is not a
## consumable you spend, it is simply the tank — which is the difference
## between this and the counter's torpedoes and repairs.
##
## Prices scale with the level already held (see the REFIT_* constants), so
## the first buy of a track is cheap and the last is a real sink for the
## mission payouts.

enum Track { OXYGEN, HULL, TORPEDO, SONAR, SPEED }

signal refit_changed

## The counter's names for the five rows, in Track order.
const NAMES := [
	"OXYGEN TANK", "HULL PLATING", "TORPEDO MAG", "SONAR ARRAY", "SCREW DRIVE",
]

var player: Player
var oxygen: Oxygen

## Purchased level per track, indexed by Track.
var _levels := [0, 0, 0, 0, 0]


## Main wires the two systems these buys grow. Connecting here rather than in
## _ready is what stops this node from guessing where anything lives.
func bind(boat: Player, tank: Oxygen) -> void:
	player = boat
	oxygen = tank


func level(track: int) -> int:
	return _levels[track]


func maxed(track: int) -> bool:
	return _levels[track] >= GameConfig.REFIT_MAX_LEVEL


## What the next level costs. Zero reads as maxed out.
func price(track: int) -> int:
	if maxed(track):
		return 0
	return roundi(GameConfig.REFIT_PRICE_BASE[track] \
		* pow(GameConfig.REFIT_PRICE_STEP[track], _levels[track]))


func can_buy(track: int) -> bool:
	return not maxed(track) and player != null and is_instance_valid(player) \
		and player.hp > 0 and player.gold >= price(track)


## Buys one level and applies it. Returns whether anything moved, so the
## counter only refreshes itself on a real purchase.
func try_buy(track: int) -> bool:
	if not can_buy(track):
		return false
	if not player.spend_gold(price(track)):
		return false
	_levels[track] += 1
	_apply(track)
	AudioDirector.play(get_tree(), &"item")
	refit_changed.emit()
	return true


func _apply(track: int) -> void:
	# Levels are inclusive: level N means the base reading plus N steps.
	var lvl: int = _levels[track]
	match track:
		Track.OXYGEN:
			oxygen.expand_tank(GameConfig.OXYGEN_MAX + GameConfig.REFIT_OXYGEN_STEP * lvl)
		Track.HULL:
			player.set_hull_capacity(GameConfig.PLAYER_MAX_HP + GameConfig.REFIT_HULL_STEP * lvl)
		Track.TORPEDO:
			player.set_ammo_capacity(GameConfig.PLAYER_MAX_AMMO + GameConfig.REFIT_AMMO_STEP * lvl)
		Track.SONAR:
			var sonar := player.sonar()
			if sonar != null:
				sonar.expand_range(GameConfig.SONAR_MAX_RANGE + GameConfig.REFIT_SONAR_STEP * lvl)
		Track.SPEED:
			player.set_speed_level(lvl)


## What the next level lends, in the counter's words.
func gain_text(track: int) -> String:
	match track:
		Track.OXYGEN:
			return "+%d s air" % GameConfig.REFIT_OXYGEN_STEP
		Track.HULL:
			return "+%d hull" % GameConfig.REFIT_HULL_STEP
		Track.TORPEDO:
			return "+%d torpedoes" % GameConfig.REFIT_AMMO_STEP
		Track.SONAR:
			return "+%d m range" % GameConfig.REFIT_SONAR_STEP
		Track.SPEED:
			return "+%d%% top speed" % int(GameConfig.REFIT_SPEED_STEP * 100.0)
		_:
			return ""