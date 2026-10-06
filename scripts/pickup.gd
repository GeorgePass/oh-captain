class_name Pickup
extends Node2D
## A drifting coin or a piece of salvage. Both are drawn by hand, like everything
## else here.
##
## Within PICKUP_MAGNET_RADIUS the player pulls them in, accelerating as they
## close, and they are collected on contact. Further out they just sit in the
## silt, which is what makes looting wrecks a reason to slow down.

enum Kind { GOLD, ITEM }

## The container node carries this, so anything spawning loot can find it.
const GROUP := "pickups"

var kind: int = Kind.GOLD
var amount := 1
## Which kind of cargo, when `kind` is ITEM. A separate field rather than a
## wider `kind`, because cargo has its own numbering and gold is not one of
## the things in it.
var item_id := 0

var _velocity := Vector2.ZERO
var _bob := 0.0
var _sweep_seed := 0.0
## Own stream, off the world seed and where this coin was dropped. The sway and
## the scatter are the least of it — a coin whose drift you cannot predict is a
## coin whose landing spot you cannot use to judge a change to anything else.
var _rng: RandomNumberGenerator


## Builds a pickup, parents it, and returns it. Returns null only if the
## player is already gone, so callers do not need to null-check the world.
static func spawn(parent: Node, at: Vector2) -> Pickup:
	if parent == null or not is_instance_valid(parent):
		return null
	var p := Pickup.new()
	p.global_position = at
	parent.add_child(p)
	return p


func _ready() -> void:
	z_index = 1
	_rng = GameConfig.seeded_at(global_position)
	_bob = _rng.randf() * TAU
	_sweep_seed = _rng.randf() * TAU
	queue_redraw()


## Flicks the pickup out in a random direction, so a killed enemy scatters its
## loot instead of stacking it in one spot.
func scatter() -> void:
	_velocity = Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(40.0, 90.0)


## Sets an explicit drift, used to lay coins out along a wreck's axis.
func nudge(direction: Vector2) -> void:
	_velocity = direction


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	var pulled := false

	if player != null and is_instance_valid(player):
		var to_player := GameConfig.wrapped_delta(global_position, player.global_position)
		var dist := to_player.length()
		if dist <= GameConfig.PICKUP_COLLECT_RADIUS:
			_collect(player)
			return
		if dist <= GameConfig.PICKUP_MAGNET_RADIUS:
			# Accelerate harder the closer it gets, so collection feels decisive
			# rather than like chasing a slow target around the hull.
			_velocity += to_player.normalized() * GameConfig.PICKUP_MAGNET_ACCEL * delta
			pulled = true

	if not pulled:
		_velocity = _velocity.move_toward(Vector2.ZERO, GameConfig.PICKUP_DRAG * 60.0 * delta)

	# Slight idle sway so scattered loot does not look pinned down.
	_bob += delta
	global_position += (_velocity + Vector2.from_angle(_bob + _sweep_seed) * 6.0) * delta
	_wrap_world()
	queue_redraw()


func _collect(player: Player) -> void:
	if kind == Kind.ITEM:
		# All or nothing. A pickup that only half fits would either eat the rest
		# or have to leave a second one behind, and both are ways of losing cargo
		# the captain never agreed to lose. Returning false leaves it drifting
		# until something has been sold and a slot has come free.
		if not player.add_item(item_id, amount):
			return
		AudioDirector.play_at(get_tree(), &"item", global_position, GameConfig.VOL_GOLD)
	else:
		player.add_gold(amount)
		AudioDirector.play_at(get_tree(), &"gold", global_position, GameConfig.VOL_GOLD)
	queue_free()


func _wrap_world() -> void:
	global_position = GameConfig.wrap_position(global_position)


func _draw() -> void:
	if kind == Kind.ITEM:
		_draw_item()
		return
	# Coin: a disc with a lighter rim, bright enough to spot at range.
	var glow := 0.35 + 0.15 * sin(_bob * 3.0)
	draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.82, 0.25, 0.22 + glow * 0.2))
	draw_circle(Vector2.ZERO, 4.6, Color(0.98, 0.79, 0.22))
	draw_arc(Vector2.ZERO, 4.6, 0.0, TAU, 14, Color(0.62, 0.45, 0.09), 1.2, true)


## Cargo: the same colour the cargo panel will show it as, so a piece of meat on
## the floor and a stack already in the hold are recognisably the same thing
## before you have read anything.
func _draw_item() -> void:
	var def := Item.get_def(item_id)
	var glow := 0.35 + 0.15 * sin(_bob * 3.0)
	draw_circle(Vector2.ZERO, 9.0, Color(def.color, 0.20 + glow * 0.2))
	draw_circle(Vector2.ZERO, 5.5, def.color)
	draw_arc(Vector2.ZERO, 5.5, 0.0, TAU, 14, def.color.darkened(0.5), 1.3, true)
