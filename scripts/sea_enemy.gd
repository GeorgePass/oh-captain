class_name SeaEnemy
extends CharacterBody2D
## Shared base for everything that hunts the player.
##
## Three states. PASSIVE drifts and ignores the hull entirely. ALERT has a
## rough idea where the player is and moves to look, but has not seen them.
## HOSTILE has the player and closes in. A sonar ping only ever produces
## ALERT: noise gives a bearing, it does not give a target, so a pinged fish
## still has to spot the hull before it commits.

enum State { PASSIVE, ALERT, HOSTILE }

const GROUP := "enemy"

signal died(enemy: Node2D)
signal hp_changed(hp: int, max_hp: int)

@export var max_hp := 5

## Overridden by each species. Fish are quick and fragile, crabs slow and
## armoured, but they share one AI so the stealth rules never change.
@export var passive_speed := GameConfig.ENEMY_PASSIVE_SPEED
@export var charge_speed := GameConfig.FISH_CHARGE_SPEED
@export var turn_rate := GameConfig.ENEMY_TURN_RATE
@export var accel := GameConfig.ENEMY_ACCEL
@export var contact_damage := GameConfig.FISH_CONTACT_DMG
@export var gold_min := GameConfig.FISH_GOLD_MIN
@export var gold_max := GameConfig.FISH_GOLD_MAX

var hp: int
var state: int = State.PASSIVE

var _wander_dir := Vector2.RIGHT
var _wander_timer := 0.0
## Seconds spent hearing the hull without breaking off.
var _alert_timer := 0.0
## Where an ALERT enemy thinks the player is. Set by a ping, refined by
## hearing, and searched on arrival.
var _last_known := Vector2.ZERO
## Counts down while searching; on zero the enemy gives up and drifts again.
var _search_timer := 0.0
## Random phase so a group of alerted enemies does not sweep in lockstep.
var _sweep_seed := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	hp = max_hp
	collision_layer = GameConfig.LAYER_ENEMY_BIT
	collision_mask = GameConfig.ENEMY_MASK
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	z_index = 0
	_wander_dir = Vector2.RIGHT.rotated(randf() * TAU)
	_sweep_seed = randf() * TAU
	hp_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	match state:
		State.HOSTILE:
			_chase(delta)
		State.ALERT:
			_investigate(delta)
		_:
			_drift(delta)
			_check_detection(delta)
	move_and_slide()
	_wrap_world()
	queue_redraw()


# --- States ------------------------------------------------------------------

func _drift(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(1.2, 3.0)
		_wander_dir = Vector2.RIGHT.rotated(randf() * TAU)
	velocity = velocity.lerp(_wander_dir * passive_speed, accel * delta)
	if velocity.length_squared() > 1.0:
		rotation = velocity.angle()


func _chase(delta: float) -> void:
	var player := get_player()
	if player == null:
		_drift(delta)
		return
	var to_player := player.global_position - global_position
	if to_player.length() < 4.0:
		return
	velocity = velocity.lerp(to_player.normalized() * charge_speed, accel * delta)
	rotation = lerp_angle(rotation, velocity.angle(), turn_rate * delta)


## Moves to the last known position, then casts about nearby before giving up.
## This is the state a ping produces: purposeful, but blind.
func _investigate(delta: float) -> void:
	var goal := _last_known
	# Within a short leash of the guess, sweep a small circle instead of
	# sitting still, so it reads as searching rather than loitering.
	var offset := global_position - _last_known
	if offset.length() < GameConfig.ENEMY_SEARCH_RADIUS:
		var sweep := Vector2.from_angle(float(Time.get_ticks_msec()) * 0.0016 + _sweep_seed)
		goal = _last_known + sweep * GameConfig.ENEMY_SEARCH_RADIUS * 0.6

	var to_goal := goal - global_position
	if to_goal.length() > 6.0:
		velocity = velocity.lerp(to_goal.normalized() * GameConfig.ENEMY_ALERT_SPEED, accel * delta)
		rotation = lerp_angle(rotation, velocity.angle(), turn_rate * delta)

	# A searching enemy can still hear the hull, and will escalate.
	_check_detection(delta)

	_search_timer -= delta
	if _search_timer <= 0.0:
		set_passive()


# --- Detection ---------------------------------------------------------------

## Stealth: a fish only hears the hull if it is close, unobstructed, and the
## player has been loud for a moment. Sprinting roughly doubles earshot, so
## going fast is the thing that gives you away, not simply existing.
## Only reachable from PASSIVE and ALERT, so a committed enemy never un-commits.
func _check_detection(delta: float) -> void:
	var player := get_player()
	if player == null:
		return
	var dist := global_position.distance_to(player.global_position)
	var earshot := GameConfig.FISH_EARSHOT_RADIUS
	if player.velocity.length() >= GameConfig.FAST_SPEED:
		earshot *= GameConfig.FISH_EARSHOT_SPRINT_MULT

	if dist > earshot:
		_alert_timer = 0.0
		return
	if GameConfig.FISH_HEARING_BLOCKED_BY_REEF and _muted_by_reef(player.global_position):
		_alert_timer = 0.0
		return

	# Linger in the open and the enemy works out something is there. Heard
	# bearing is refined as it goes, so a searching enemy homes in a little.
	_alert_timer += delta
	_last_known = player.global_position
	if _alert_timer >= GameConfig.FISH_ALERT_DELAY:
		set_hostile()


## Reefs between the hull and the enemy muffle it, same as they block the ping.
func _muted_by_reef(player_pos: Vector2) -> bool:
	if global_position.is_equal_approx(player_pos):
		return false
	var query := PhysicsRayQueryParameters2D.create(
		global_position, player_pos, GameConfig.LAYER_REEF_BIT)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


# --- State changes -----------------------------------------------------------

## A ping or a near miss: something is out there, go and look. Deliberately
## not hostile, so noise alone can never start a fight.
func set_alert(approx_player_pos: Vector2 = Vector2.INF) -> void:
	if state == State.HOSTILE:
		return
	if state == State.ALERT:
		# Already searching: keep the better fix if we have one.
		if _last_known.is_finite() and not approx_player_pos.is_finite():
			return
	if approx_player_pos.is_finite():
		_last_known = approx_player_pos
	_search_timer = GameConfig.ENEMY_ALERT_TIMEOUT
	state = State.ALERT


## Has actually seen the hull. From here it tracks the player directly.
func set_hostile() -> void:
	if state == State.HOSTILE:
		return
	state = State.HOSTILE
	if velocity.length() < passive_speed:
		velocity = _wander_dir * passive_speed


func set_passive() -> void:
	state = State.PASSIVE
	_alert_timer = 0.0
	_search_timer = 0.0


func is_alert() -> bool:
	return state == State.ALERT


func is_hostile() -> bool:
	return state == State.HOSTILE


# --- Damage ------------------------------------------------------------------

func take_damage(amount: int) -> void:
	if hp <= 0:
		return
	hp -= amount
	hp_changed.emit(hp, max_hp)
	# Taking a hit always gives away where the attacker is.
	set_hostile()
	if hp <= 0:
		_drop_loot()
		died.emit(self)
		queue_free()


## Scatters coins and, sometimes, a torpedo crate where the enemy died.
## Spawned into the shared pickup container rather than our own parent, so
## wrecks and enemies both drop into one place that is easy to inspect.
func _drop_loot() -> void:
	var parent := get_tree().get_first_node_in_group(Pickup.GROUP) as Node
	if parent == null:
		parent = get_parent()
	if parent == null:
		return
	var gold := randi_range(gold_min, gold_max)
	var coins := clampi(gold / 3, 2, 5)
	for i in coins:
		var coin := Pickup.spawn(parent, global_position)
		coin.amount = maxi(1, gold / coins)
		coin.scatter()
	if randf() < GameConfig.ENEMY_AMMO_CHANCE:
		var crate := Pickup.spawn(parent, global_position)
		crate.kind = Pickup.Kind.AMMO
		crate.amount = GameConfig.ENEMY_AMMO_DROP
		crate.scatter()


func get_player() -> Player:
	return get_tree().get_first_node_in_group(Player.GROUP) as Player


func _wrap_world() -> void:
	var p := global_position
	var h := GameConfig.WORLD_HALF
	if p.x > h:
		p.x -= GameConfig.WORLD_SIZE
	elif p.x < -h:
		p.x += GameConfig.WORLD_SIZE
	if p.y > h:
		p.y -= GameConfig.WORLD_SIZE
	elif p.y < -h:
		p.y += GameConfig.WORLD_SIZE
	global_position = p
