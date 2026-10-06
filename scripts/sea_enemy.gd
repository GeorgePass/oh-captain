class_name SeaEnemy
extends CharacterBody2D
## Shared base for everything that hunts the player.
##
## Four states. PASSIVE drifts and ignores the hull entirely. ALERT has a rough
## idea where the player is and moves to look, but has not seen them. HOSTILE
## has the player and closes in. FLEEING gives up and runs for open water, which
## is terminal: a broken enemy that decides to leave does not change its mind.
##
## A sonar ping only ever produces ALERT: noise gives a bearing, it does not give
## a target, so a pinged fish still has to spot the hull before it commits.

enum State { PASSIVE, ALERT, HOSTILE, FLEEING }

const GROUP := "enemy"

## Lock-on markers are drawn in the world as well as on the radar. The ring is
## deliberately faint: most enemies in sight are lockable, so the ring is
## background information and the bracket has to be the thing your eye lands on.
const LOCK_RING_COLOR := Color(0.62, 0.86, 0.95, 0.40)
const LOCK_BRACKET_COLOR := Color(1.0, 0.86, 0.35)

## Typed to the creature rather than to Node2D, so everything downstream —
## the spawner's relay, the death ripple, the sonar contact it drops — receives
## an enemy it can act on directly. It used to be Node2D and every consumer
## re-guessed what it was holding.
signal died(enemy: SeaEnemy)
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

## Set by the player once per physics frame: whether this enemy is currently
## eligible for lock-on. Drives the in-sight ring drawn in the world.
var lockable := false
## Set alongside `lockable`, true only for the one enemy actually locked.
var locked := false

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
## Counts down to the next swimming sound. This is deliberately the only way to
## sense a passive enemy, and it is a fair trade: it works without a ping, but
## only if you are already close enough to hear it.
var _swim_timer := 0.0
## Seconds of lock-on eligibility left after drifting out of sight. The player
## tops this up every frame while the enemy is in sight or on a sonar contact;
## left alone it simply runs out.
var _lock_grace := 0.0

## Own stream, off the world seed and where this creature was put in the water.
## Per-creature rather than shared so one fish taking an extra roll cannot shift
## another's sequence — otherwise the tenth thing you meet in the water is a
## lottery ticket whose number depends on how long the first nine survived.
var _rng: RandomNumberGenerator
## Search sweep, advanced by the frame clock rather than read off the wall
## clock. The wall-clock version gave every creature a sweep phase set by when
## the process happened to start, which is variation the seed cannot reach.
var _sweep_phase := 0.0


func _ready() -> void:
	_rng = GameConfig.seeded_at(global_position)
	add_to_group(GROUP)
	hp = max_hp
	collision_layer = GameConfig.LAYER_ENEMY_BIT
	collision_mask = GameConfig.ENEMY_MASK
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	z_index = 0
	_wander_dir = Vector2.RIGHT.rotated(_rng.randf() * TAU)
	_sweep_seed = _rng.randf() * TAU
	_swim_timer = _rng.randf_range(0.5, GameConfig.ENEMY_SWIM_MAX_GAP)
	hp_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	_lock_grace = maxf(_lock_grace - delta, 0.0)
	match state:
		State.FLEEING:
			_flee(delta)
		State.HOSTILE:
			_chase(delta)
		State.ALERT:
			_investigate(delta)
		_:
			_drift(delta)
			_check_detection(delta)
	move_and_slide()
	_wrap_world()
	_tick_swim(delta)
	queue_redraw()


# --- Fleeing -----------------------------------------------------------------

## Runs directly away from the hull. Fleeing enemies deal no contact damage:
## they are leaving, and bumping into one on the way past should not be a
## punishment for it having given up.
func _flee(delta: float) -> void:
	var player := get_player()
	if player == null:
		_drift(delta)
		return
	var away := global_position - player.global_position
	if away.length() < 1.0:
		away = Vector2.RIGHT.rotated(rotation)
	velocity = velocity.lerp(away.normalized() * GameConfig.ENEMY_FLEE_SPEED, accel * delta)
	rotation = lerp_angle(rotation, velocity.angle(), turn_rate * delta)


## Called by Main when any enemy dies nearby. A coward bolts at the sight of it
## regardless of how healthy it is; anything tougher carries on hunting. This is
## what makes a kill dangerous to make in the wrong place, and it is deliberately
## not tied to HP: there is no damage small enough to be survivable and still
## leave a fish willing to stand its ground.
func on_neighbour_died(at: Vector2) -> void:
	if state == State.FLEEING or not coward():
		return
	if global_position.distance_to(at) > GameConfig.ENEMY_FLEE_PANIC_RADIUS:
		return
	set_fleeing()


## Terminal. Once an enemy decides to run it keeps running, and it can no longer
## be alerted or committed: a creature that has given up on you cannot be talked
## back into the fight by a ping.
func set_fleeing() -> void:
	if state == State.FLEEING:
		return
	state = State.FLEEING
	_alert_timer = 0.0
	_search_timer = 0.0
	# Retiring, not attacking: a clean run for it rather than a last screech.
	velocity = velocity.normalized() * maxf(velocity.length(), passive_speed)


func is_fleeing() -> bool:
	return state == State.FLEEING


## Occasional rustle of movement, and the only way to notice a creature that has
## not reacted to you. Only emitted when the player is within roughly twice
## earshot: past that the sound is inaudible anyway, so playing it would just
## fill the pool.
func _tick_swim(delta: float) -> void:
	if velocity.length() < passive_speed * 0.5:
		_swim_timer = _rng.randf_range(1.5, GameConfig.ENEMY_SWIM_MAX_GAP)
		return
	_swim_timer -= delta
	if _swim_timer > 0.0:
		return
	_swim_timer = _rng.randf_range(GameConfig.ENEMY_SWIM_MIN_GAP, GameConfig.ENEMY_SWIM_MAX_GAP)

	var player := get_player()
	if player == null or not is_instance_valid(player):
		return
	var audible := GameConfig.FISH_EARSHOT_RADIUS * GameConfig.ENEMY_SWIM_AUDIBLE_MULT
	if global_position.distance_to(player.global_position) > audible:
		return
	AudioDirector.play_at(get_tree(), &"swim", global_position, GameConfig.VOL_ENEMY)


# --- States ------------------------------------------------------------------

func _drift(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = _rng.randf_range(1.2, 3.0)
		_wander_dir = Vector2.RIGHT.rotated(_rng.randf() * TAU)
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
		_sweep_phase += delta * GameConfig.ENEMY_SEARCH_SWEEP_RATE
		var sweep := Vector2.from_angle(_sweep_phase + _sweep_seed)
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
	if state == State.HOSTILE or state == State.FLEEING:
		return
	if state == State.ALERT:
		# Already searching: keep the better fix if we have one.
		if _last_known.is_finite() and not approx_player_pos.is_finite():
			return
	if approx_player_pos.is_finite():
		_last_known = approx_player_pos
	_search_timer = GameConfig.ENEMY_ALERT_TIMEOUT
	state = State.ALERT
	# A questioning cry, not an attack. Played only on the transition, which
	# the guard above already returns early for.
	_cry(false)


## Has actually seen the hull. From here it tracks the player directly.
func set_hostile() -> void:
	if state == State.HOSTILE or state == State.FLEEING:
		return
	state = State.HOSTILE
	if velocity.length() < passive_speed:
		velocity = _wander_dir * passive_speed
	_cry(true)


## Positional, so a cry off the port bow tells you which way to look. Deliberately
## the only alert the audio system gives: there is no separate "something is
## alerted" cue, because the creatures announcing themselves is more in keeping
## with the rest of the game than a HUD tone.
func _cry(urgent: bool) -> void:
	if is_inside_tree():
		AudioDirector.play_at(get_tree(), AudioDirector.cry_key(urgent, species()),
			global_position, GameConfig.VOL_ENEMY)


func set_passive() -> void:
	if state == State.FLEEING:
		return
	state = State.PASSIVE
	_alert_timer = 0.0
	_search_timer = 0.0


## Lock-on grace window, owned here but driven by the player.
func set_lock_grace(seconds: float) -> void:
	_lock_grace = maxf(seconds, 0.0)


func lock_grace_left() -> float:
	return _lock_grace


func is_alert() -> bool:
	return state == State.ALERT


func is_hostile() -> bool:
	return state == State.HOSTILE


## Sound key species. Overridden by each subclass so blips and cries can be
## told apart without asking what class something is.
func species() -> StringName:
	return &"fish"


## What this creature looks and sounds like, resolved from its identity.
##
## The radar and the audio both ask this rather than testing `is` against a
## species class, so a new creature is described entirely by its entry in
## Species.PROFILES and cannot be half-remembered in one place and not another.
## Null means nothing is registered under this id, which is a mistake worth
## surfacing rather than papering over with a default voice.
func profile() -> Species.Profile:
	return Species.profile_for(species())


## Whether this creature gives up rather than fight it out. Fish are cowards:
## one hit of any size and they run, and a kill nearby is enough on its own.
## The armoured things have to be worn down before they break.
func coward() -> bool:
	return false


# --- Lock marker -------------------------------------------------------------

## Drawn by each species at the end of its own `_draw`, so the markers sit on
## top of the body rather than under it.
##
## A faint ring means "you could lock this". The bracket means "you have", and is
## corners rather than a circle specifically so the two states never get read as
## the same indicator at a glance.
func _draw_lock_marker(body_radius: float) -> void:
	if locked:
		var r := body_radius + 11.0
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			draw_line(corner * r, corner * (r + 9.0), LOCK_BRACKET_COLOR, 2.5)
		return
	if not lockable:
		return
	draw_arc(Vector2.ZERO, body_radius + 8.0, 0.0, TAU, 32, LOCK_RING_COLOR, 1.5, true)


# --- Damage ------------------------------------------------------------------

func take_damage(amount: int) -> void:
	if hp <= 0:
		return
	hp -= amount
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		_drop_loot()
		died.emit(self)
		queue_free()
		return

	# Hurt and still breathing: a coward abandons the fight outright, anything
	# else turns on whoever did it. Checked before `set_hostile` so a fish that
	# is about to run does not also shriek a hunting cry it never means.
	if coward() or hp <= max_hp / GameConfig.ENEMY_FLEE_HP_DIVISOR:
		set_fleeing()
		return
	# Taking a hit always gives away where the attacker is.
	set_hostile()


## Scatters coins and, sometimes, a torpedo crate where the enemy died.
## Spawned into the shared pickup container rather than our own parent, so
## wrecks and enemies both drop into one place that is easy to inspect.
func _drop_loot() -> void:
	var parent := get_tree().get_first_node_in_group(Pickup.GROUP) as Node
	if parent == null:
		parent = get_parent()
	if parent == null:
		return
	var gold := _rng.randi_range(gold_min, gold_max)
	var coins := clampi(gold / 3, 2, 5)
	for i in coins:
		var coin := Pickup.spawn(parent, global_position)
		coin.amount = maxi(1, gold / coins)
		coin.scatter()
	if _rng.randf() < GameConfig.ENEMY_AMMO_CHANCE:
		var crate := Pickup.spawn(parent, global_position)
		crate.kind = Pickup.Kind.AMMO
		crate.amount = GameConfig.ENEMY_AMMO_DROP
		crate.scatter()


func get_player() -> Player:
	return get_tree().get_first_node_in_group(Player.GROUP) as Player


func _wrap_world() -> void:
	global_position = GameConfig.wrap_position(global_position)
