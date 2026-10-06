class_name Pickup
extends Node2D
## A drifting coin or torpedo crate. Both are drawn by hand, like everything
## else here.
##
## Within PICKUP_MAGNET_RADIUS the player pulls them in, accelerating as they
## close, and they are collected on contact. Further out they just sit in the
## silt, which is what makes looting wrecks a reason to slow down.

enum Kind { GOLD, AMMO }

## The container node carries this, so anything spawning loot can find it.
const GROUP := "pickups"

var kind: int = Kind.GOLD
var amount := 1

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
	if kind == Kind.AMMO:
		player.add_ammo(amount)
		AudioDirector.play_at(get_tree(), &"ammo", global_position, GameConfig.VOL_GOLD)
	else:
		player.add_gold(amount)
		AudioDirector.play_at(get_tree(), &"gold", global_position, GameConfig.VOL_GOLD)
	queue_free()


func _wrap_world() -> void:
	global_position = GameConfig.wrap_position(global_position)


func _draw() -> void:
	if kind == Kind.AMMO:
		_draw_crate()
		return
	# Coin: a disc with a lighter rim, bright enough to spot at range.
	var glow := 0.35 + 0.15 * sin(_bob * 3.0)
	draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.82, 0.25, 0.22 + glow * 0.2))
	draw_circle(Vector2.ZERO, 4.6, Color(0.98, 0.79, 0.22))
	draw_arc(Vector2.ZERO, 4.6, 0.0, TAU, 14, Color(0.62, 0.45, 0.09), 1.2, true)


func _draw_crate() -> void:
	var box := PackedVector2Array([
		Vector2(8, -6), Vector2(8, 6), Vector2(-8, 6), Vector2(-8, -6),
	])
	draw_colored_polygon(box, Color(0.32, 0.58, 0.62))
	draw_polyline(GameConfig.closed(box), Color(0.16, 0.32, 0.36), 1.6, true)
	# A round mark on the face so a crate is not mistaken for a coin.
	draw_arc(Vector2.ZERO, 3.2, 0.0, TAU, 12, Color(0.78, 0.93, 0.95), 1.4, true)
