class_name MissionDirector
extends Node
## The harbourmaster's three errands, and the only place their rules live.
##
## One mission at a time, never aborted. Acceptance happens at the harbour
## counter; a mission then runs OFFERED -> ACTIVE -> objective met -> paid and
## gone. "Objective met" is not the end - every errand is paid on returning to
## harbour with the objective met, which is what makes each one a round trip
## rather than a one-way task.
##
## The three errands differ only in how the objective is met:
##   DELIVERY  - the harbour hands you a crate; docking at the outpost with it
##               aboard delivers it.
##   KILL      - sink KILL_MISSION_TARGET fish. Only fish count.
##   RECOVER   - a crate lies at a known wreck while the errand is active;
##               the moment one is in the hold the objective is met.
##
## Mission cargo is Item.CARGO_CRATE: worth nothing, so the counter refuses to
## sell it, and it can be dropped over the side and picked up again like any
## other cargo - the errand only cares that it is aboard at the right moment.

enum ID { NONE = 0, DELIVERY = 1, KILL = 2, RECOVER = 3 }

signal mission_changed(active_mission: int, objective_met: bool)
signal mission_paid(reward: int)

## One contract as the harbour counter presents it.
class Info extends RefCounted:
	var id: int
	var name: String
	var desc: String
	var reward: int

	func _init(id_: int = 0, name_: String = "", desc_: String = "", reward_: int = 0) -> void:
		id = id_
		name = name_
		desc = desc_
		reward = reward_

## The three errands, in the order the counter lists them.
static var LIST: Array[Info] = []


static func _static_init() -> void:
	LIST = [
		Info.new(ID.DELIVERY, "CARGO RUN", "deliver the crate to the outpost",
			GameConfig.MISSION_REWARD_DELIVERY),
		Info.new(ID.KILL, "HUNT", "sink %d fish" % GameConfig.KILL_MISSION_TARGET,
			GameConfig.MISSION_REWARD_KILL),
		Info.new(ID.RECOVER, "WRECK", "recover the crate from the wreck",
			GameConfig.MISSION_REWARD_RECOVER),
	]


static func info_for(id: int) -> Info:
	return LIST[id - 1]


## Which errand is under way, or ID.NONE.
var active := ID.NONE
## Whether the current objective is done and only the return remains.
var objective_met := false
## How many of the hunt's fish have been sunk. Zeroed when the hunt is taken.
var kills := 0
## A line for the harbour counter: why acceptance was refused, or the last
## payout.
var notice := ""

var player: Player
var spawner: Spawner

@onready var wreck_container: Node2D = $"../World/Wrecks"

## The errand wreck, built once with the world.
var _wreck: Wreck
## The crate lying at the wreck while the recover errand is active. Tracked so
## it can be tidied away when the errand ends, whichever way it ends.
var _recover_crate: Pickup


func _ready() -> void:
	_build_mission_wreck()


## Main wires the actors this reads. Connecting here rather than in _ready is
## what stops this node from guessing where the player and the spawner live.
func bind(target: Player, spawner_node: Spawner) -> void:
	player = target
	spawner = spawner_node
	spawner.enemy_died.connect(_on_enemy_died)
	player.inventory_changed.connect(_on_inventory_changed)


# --- Accepting ---------------------------------------------------------------

func can_accept(id: int) -> bool:
	if active != ID.NONE:
		return false
	if id == ID.DELIVERY and (player == null or player.cargo.size() >= GameConfig.INV_CAPACITY):
		notice = "Make room — the hold must take the crate."
		return false
	return id > ID.NONE and id <= ID.RECOVER


func accept(id: int) -> bool:
	if not can_accept(id):
		return false
	active = id
	objective_met = false
	kills = 0
	notice = ""
	if id == ID.DELIVERY:
		# The harbour hands over the crate it wants carried.
		player.add_item(Item.CARGO_CRATE, 1)
	elif id == ID.RECOVER:
		_spawn_recover_crate()
	AudioDirector.play(get_tree(), &"item")
	mission_changed.emit(active, objective_met)
	return true


# --- Objective progress ------------------------------------------------------

## A death anywhere in the water. Only the hunt listens, and only to fish:
## a crab is a crab, and sinking one is not an errand.
func _on_enemy_died(dead: SeaEnemy) -> void:
	if active != ID.KILL or objective_met:
		return
	var profile := dead.profile()
	if profile == null or profile.id != &"fish":
		return
	kills += 1
	if kills >= GameConfig.KILL_MISSION_TARGET:
		objective_met = true
		AudioDirector.play(get_tree(), &"mission", GameConfig.VOL_GOLD)
	mission_changed.emit(active, objective_met)


## The hold changed - a pickup taken, a drop made, a delivery handed over. The
## recover errand is met the moment its crate is aboard, no matter how it got
## there, and stays met even if it is dropped again afterwards.
func _on_inventory_changed() -> void:
	if active != ID.RECOVER or objective_met:
		return
	if player.has_item(Item.CARGO_CRATE):
		objective_met = true
		AudioDirector.play(get_tree(), &"mission", GameConfig.VOL_GOLD)
		mission_changed.emit(active, objective_met)


# --- Docks -------------------------------------------------------------------

## Docking at the outpost is what completes the delivery errand. Called by
## Main so the pause and the hand-in happen in the same breath.
func on_outpost_docked(docked: bool) -> void:
	if not docked or active != ID.DELIVERY or objective_met:
		return
	if player != null and player.take_item(Item.CARGO_CRATE):
		objective_met = true
		AudioDirector.play(get_tree(), &"mission", GameConfig.VOL_GOLD)
		mission_changed.emit(active, objective_met)


## Returning to the harbour with the objective met is the whole payoff of an
## errand: the mission pays and is gone, and there is no way to take it back.
func on_harbor_docked(docked: bool) -> void:
	if not docked or active == ID.NONE or not objective_met:
		return
	var info := info_for(active)
	var reward := info.reward
	player.add_gold(reward)
	notice = "%s COMPLETE  —  +%d g" % [info.name, reward]
	_clear_recover_crate()
	active = ID.NONE
	objective_met = false
	mission_paid.emit(reward)
	AudioDirector.play(get_tree(), &"gold", GameConfig.VOL_GOLD)
	AudioDirector.play(get_tree(), &"mission", GameConfig.VOL_GOLD)
	mission_changed.emit(active, objective_met)


# --- Text --------------------------------------------------------------------

## The line under the radar: an objective, or a counter, or nothing.
func hud_text() -> String:
	if active == ID.NONE:
		return ""
	if objective_met:
		return "%s  —  RETURN TO HARBOR" % info_for(active).name
	return "%s  —  %s" % [info_for(active).name, progress_text()]


## The objective in plain words, counter included.
func progress_text() -> String:
	match active:
		ID.DELIVERY:
			return "DELIVER THE CRATE TO THE OUTPOST"
		ID.KILL:
			return "SINK %d / %d FISH" % [kills, GameConfig.KILL_MISSION_TARGET]
		ID.RECOVER:
			return "RECOVER THE CRATE FROM THE WRECK"
		_:
			return ""


## What the outpost screen says about itself while you are alongside.
func outpost_note() -> String:
	if active == ID.DELIVERY and objective_met:
		return "The crate is ashore. Return to the harbour for payment."
	if active == ID.DELIVERY:
		return "Bring the harbourmaster's crate alongside to deliver it."
	return "A supply post. The tank tops up here; nothing is bought or sold."


# --- Recover errand site -----------------------------------------------------

## The wreck the third errand points at is a fixture like the outpost: always
## in the water, teal-hulled and wearing a crate so it can be told from the
## other twenty-one. What is not always there is the crate-holding pickup at
## its feet, which only appears while the errand is actually under way.
func _build_mission_wreck() -> void:
	if wreck_container == null:
		return
	var wreck := Wreck.new()
	wreck.mission_site = true
	wreck.length = 190.0
	wreck.beam = 46.0
	wreck.tilt = 0.12
	wreck.position = GameConfig.MISSION_WRECK_POSITION
	wreck.rotation = 0.6
	wreck_container.add_child(wreck)
	_wreck = wreck


func _spawn_recover_crate() -> void:
	_clear_recover_crate()
	var parent := get_tree().get_first_node_in_group(Pickup.GROUP)
	if parent == null:
		return
	var crate := Pickup.spawn(parent, GameConfig.MISSION_WRECK_POSITION + Vector2(0.0, 50.0))
	if crate == null:
		return
	crate.kind = Pickup.Kind.ITEM
	crate.item_id = Item.CARGO_CRATE
	crate.amount = 1
	crate.attracted = true
	_recover_crate = crate


func _clear_recover_crate() -> void:
	if _recover_crate != null and is_instance_valid(_recover_crate):
		_recover_crate.queue_free()
	_recover_crate = null