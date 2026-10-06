class_name SeaEnemy
extends CharacterBody2D
## Shared base for everything that hunts the player.
##
## Four states. PASSIVE drifts and ignores the hull entirely. ALERT has a rough
## idea where the player is and moves to look, but has not seen them. HOSTILE
## has the player and closes in. FLEEING gives up and runs for open water.
##
## Two rules run through all of it. Sound and sight are kept apart: a noise puts
## a creature on ALERT pointed at where it came from and can go no further, while
## distance held for a moment is what makes it HOSTILE. A bearing is not a
## target, so nothing that makes a noise — a ping, a launch, a death nearby —
## can start a fight on its own. And what decides the fight once it is seen is
## health, not temperament: a fish that has never been touched still comes for
## you, and one that has been hurt runs.
## FLEEING is not terminal either: a creature that bolts can turn and fight if
## it is healthy enough and sees you again, and it drifts again once you are gone.

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
## Where an ALERT enemy thinks the sound came from. Set by a ping, by a launch,
## or by hearing the hull, and searched on arrival.
var _last_known := Vector2.ZERO
## Linger budget for the place the sound came from. Armed on every new sound,
## but it only drains once the creature has actually arrived — see `_investigate`.
var _search_timer := 0.0
## Seconds of the hull staying in sight, accumulated while it is inside sight
## range and cleared the moment it is not. Reaching `FISH_SIGHT_DELAY` is what
## turns a sighting into a decision; hearing never touches this.
var _sight_timer := 0.0
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
	_give_up_if_out_of_range()
	match state:
		State.FLEEING:
			_flee(delta)
			# Bolting is not a hiding place. A creature that is hurt badly enough
			# to run keeps running; one that was only grazed turns and fights if
			# the hull stays in sight long enough.
			_check_senses(delta)
		State.HOSTILE:
			_chase(delta)
		State.ALERT:
			_investigate(delta)
		_:
			_drift(delta)
			_check_senses(delta)
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
	var away := GameConfig.wrapped_delta(player.global_position, global_position)
	if away.length() < 1.0:
		away = Vector2.RIGHT.rotated(rotation)
	velocity = velocity.lerp(away.normalized() * GameConfig.ENEMY_FLEE_SPEED, accel * delta)
	rotation = lerp_angle(rotation, velocity.angle(), turn_rate * delta)


## Called by Main when any enemy dies nearby. Something went off close enough to
## be worth looking at, so everything in earshot goes to look — which is what
## makes a kill dangerous to make in the wrong place.
##
## It does not scatter them. A death is an event, not a condition, and it stops
## being true the moment the water closes over it; only something still true
## next frame, like how hurt they are, is allowed to turn a creature around on
## the spot. So this alerts rather than alarms, and if whoever arrives finds the
## hull it is the health check that decides whether they fight or run.
func on_neighbour_died(at: Vector2) -> void:
	if state == State.HOSTILE or state == State.FLEEING:
		return
	if GameConfig.wrapped_delta(at, global_position).length() > GameConfig.ENEMY_FLEE_PANIC_RADIUS:
		return
	set_alert(at)


## Gives up on the hull and runs for open water. Not terminal: a healthy creature
## that bolts can still turn and fight if it sees the hull again, and one that
## has outrun the pursuit goes back to drifting on its own. A ping cannot call it
## back, though — noise does not talk a broken animal out of leaving.
func set_fleeing() -> void:
	if state == State.FLEEING:
		return
	state = State.FLEEING
	_sight_timer = 0.0
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
	if GameConfig.wrapped_delta(player.global_position, global_position).length() > audible:
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
	var to_player := GameConfig.wrapped_delta(global_position, player.global_position)
	if to_player.length() < 4.0:
		return
	velocity = velocity.lerp(to_player.normalized() * charge_speed, accel * delta)
	rotation = lerp_angle(rotation, velocity.angle(), turn_rate * delta)


## Moves to where the sound came from, then casts about nearby before giving up.
## This is the state a ping or a launch produces: purposeful, but blind.
##
## The linger budget drains only once the creature has actually arrived. A sound
## across the map buys the whole swim to it — counting down from the alert spent
## the budget on the journey, so a long-range investigation always handed back a
## creature that had never reached the place it was sent to look at.
func _investigate(delta: float) -> void:
	var goal := _last_known
	# Within a short leash of the sound, sweep a small circle instead of
	# sitting still, so it reads as searching rather than loitering. This same
	# leash is what counts as arriving.
	var arrived := GameConfig.wrapped_delta(_last_known, global_position) \
		.length() < GameConfig.ENEMY_SEARCH_RADIUS
	if arrived:
		_search_timer -= delta
		_sweep_phase += delta * GameConfig.ENEMY_SEARCH_SWEEP_RATE
		var sweep := Vector2.from_angle(_sweep_phase + _sweep_seed)
		goal = _last_known + sweep * GameConfig.ENEMY_SEARCH_RADIUS * 0.6

	var to_goal := GameConfig.wrapped_delta(global_position, goal)
	if to_goal.length() > 6.0:
		velocity = velocity.lerp(to_goal.normalized() * GameConfig.ENEMY_ALERT_SPEED, accel * delta)
		rotation = lerp_angle(rotation, velocity.angle(), turn_rate * delta)

	# A searching creature is still listening and looking while it works, and
	# either one can end the search early by finding what it came for.
	_check_senses(delta)
	if state != State.ALERT:
		# It just committed or bolted. Falling through would run this frame's
		# linger budget against the state it has already left, cancelling a
		# flee on the very frame it started.
		return
	if arrived and _search_timer <= 0.0:
		set_passive()


# --- Detection ---------------------------------------------------------------

## Whether this creature, as it stands right now, runs rather than fights.
##
## Health, and only health. Health is the one answer that is still true on the
## next frame, which is what makes it the right thing to consult when a creature
## sees the hull: a fish that has never been touched is not a fish that wants to
## be somewhere else, so it comes. Whether a species treats a fresh wound as
## reason enough on its own is `coward()`, and that is only asked once something
## has actually hit it.
func _wants_flee() -> bool:
	return hp * GameConfig.ENEMY_FLEE_HP_DIVISOR <= max_hp


## The single place where seeing the hull becomes a decision. Both routes in —
## hearing it during a search, and noticing it while drifting — come through
## here, so there is one answer to "does it come for me" rather than two that can
## drift apart.
func _commit_or_flee() -> void:
	if _wants_flee():
		set_fleeing()
	else:
		set_hostile()


## Stops caring once the hull is out of reach, from any committed state.
##
## Without this a chase never ends. The water wraps, so a hostile fish will follow
## you round the map indefinitely and one torpedo stops meaning anything; the
## crab was meant to be a threat you cannot simply outrun *and forget*, not one
## that runs you down forever. Measured past the sonar so that a ping at maximum
## range still has its search to run.
func _give_up_if_out_of_range() -> void:
	if state == State.PASSIVE:
		return
	var player := get_player()
	if player == null or not is_instance_valid(player):
		return
	var d := GameConfig.wrapped_delta(global_position, player.global_position).length()
	if d > GameConfig.ENEMY_GIVE_UP_RANGE:
		set_passive()


## The two senses, side by side, because they answer different questions.
##
## Hearing asks whether something is making noise nearby and, if so, points the
## creature at the source. It reaches further when the hull is loud, reefs block
## it, and it can do no more than put a creature on ALERT: a bearing is not a
## target, so hearing on its own never raises anything.
##
## Sight asks whether the hull is right there, and distance held for a moment is
## the only thing that has ever made a creature commit. An alert creature sees
## further than a resting one because it is looking, which is the whole
## difference between a search that finds what it was sent for and one that
## walks to the noise, glances around from too far away, and gives up.
##
## Reached from PASSIVE, ALERT and FLEEING — a committed enemy is never asked,
## it already has what it came for.
func _check_senses(delta: float) -> void:
	var player := get_player()
	if player == null:
		return
	var dist := GameConfig.wrapped_delta(global_position, player.global_position).length()

	# Hearing. Tracked continuously rather than accumulated: a hull rustling
	# this close is already a signal worth acting on, and the fix it leaves is
	# exact because a local sound tells you precisely where it is.
	var earshot := GameConfig.FISH_EARSHOT_RADIUS
	if player.velocity.length() >= GameConfig.FAST_SPEED:
		earshot *= GameConfig.FISH_EARSHOT_SPRINT_MULT
	var audible := dist <= earshot
	if audible and GameConfig.FISH_HEARING_BLOCKED_BY_REEF:
		audible = not _muted_by_reef(player.global_position)
	if audible:
		set_alert(player.global_position)

	# Sight. Reaching the delay is a decision; falling out of range wipes it, so
	# a hull that crosses the edge is seen without being dwelt on.
	var sight := GameConfig.FISH_SIGHT_RADIUS
	if state == State.ALERT:
		sight *= GameConfig.FISH_SIGHT_ALERT_MULT
	if dist > sight:
		_sight_timer = 0.0
		return
	_sight_timer += delta
	if _sight_timer >= GameConfig.FISH_SIGHT_DELAY:
		_commit_or_flee()


## Reefs between the hull and the enemy muffle it, same as they block the ping.
func _muted_by_reef(player_pos: Vector2) -> bool:
	return GameConfig.reef_between(get_world_2d().direct_space_state,
		global_position, player_pos)


# --- Sound -------------------------------------------------------------------

## Everything that makes a noise in the water goes through here: a ping, a
## torpedo launch, and anything added later. It points whatever is close enough
## at the origin and puts it on ALERT, and that is the whole of it — sound is a
## bearing, never a target, so no action the player can take will ever commit a
## creature on its own. What finds you is being seen after you have arrived.
##
## Callers keep their own occlusion rather than this carrying any. A ping checks
## for reefs because a ring has a real path across the water to be blocked
## along; a launch is a bang that arrives wherever it arrives.
static func hear_noise(tree: SceneTree, at: Vector2, radius: float) -> void:
	if tree == null:
		return
	for n in tree.get_nodes_in_group(GROUP):
		var enemy := n as SeaEnemy
		if enemy == null or not is_instance_valid(enemy):
			continue
		if GameConfig.wrapped_delta(at, enemy.global_position).length() > radius:
			continue
		enemy.set_alert(at)


# --- State changes -----------------------------------------------------------

## A sound made somewhere: something is out there, go and look. Deliberately
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
##
## Reachable from FLEEING: a creature that ran can turn round, and it is the
## health check in `_commit_or_flee` that keeps a badly broken one running. The
## gate is deliberately not in here, so there is a single answer to whether
## seeing the player means fight or flight.
func set_hostile() -> void:
	if state == State.HOSTILE:
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
	if not is_inside_tree() or _profile == null:
		return
	AudioDirector.play_at(get_tree(), AudioDirector.cry_key(urgent, _profile.id),
		global_position, GameConfig.VOL_ENEMY)


## Back to drifting. Also how a run ends: once the hull is out of reach there is
## nothing left to run from, so a fleeing creature settles again rather than
## spending the rest of the dive bolting at empty water.
func set_passive() -> void:
	state = State.PASSIVE
	_sight_timer = 0.0
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


## What this creature looks and sounds like.
##
## Handed over rather than looked up. It used to declare an id of its own and
## then ask Species for the profile matching it, which meant the declaration and
## the registry were two independent statements of the same fact with nothing to
## make them agree. They did not agree, once: a creature whose id was not
## registered spawned, swam, chased and died perfectly normally, and was silent
## with no radar halo, because the audio streams were filed under the id the
## registry knew and it was not this one.
##
## Whoever creates the creature passes the profile it came from. There is no way
## to state an identity that the registry has not already agreed to.
var _profile: Species.Profile


## Adopts a species. Called before the node enters the tree, so a creature is
## never briefly nameless.
func apply_profile(p: Species.Profile) -> void:
	if p == null:
		push_error("SeaEnemy: %s spawned with no species profile, so it has no voice" % name)
		return
	_profile = p


func profile() -> Species.Profile:
	return _profile


## Whether a wound is reason enough to run on its own, whatever the health left.
## Fish are cowards in that sense: one hit of any size and they go. It is asked
## only once something has actually hit them — seeing the hull is decided by
## health, not by this. The armoured things have to be worn down first.
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

	# Hurt and still breathing. A species that bolts at any wound goes straight
	# out; everything else asks the same question sight asks, because a hit is
	# just health plus an attacker and health is what the answer is made of.
	# Checked before the commit so a fish about to run does not also shriek a
	# hunting cry it never means.
	if coward():
		set_fleeing()
		return
	# Taking a hit always gives away where the attacker is.
	_commit_or_flee()


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
