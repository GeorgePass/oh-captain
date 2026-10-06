class_name Sonar
extends Node2D
## Owns sonar mode, ping cooldowns, and the live contact list.
##
## A "contact" is a revealed enemy plus a decaying timer. Contacts feed the HUD
## radar at long range; locking onto something short of that is the player's
## own eyes, handled in Player.lockable().

enum Mode { PASSIVE, ACTIVE }

const RING_SCENE := "res://scenes/sonar_ring.tscn"

signal mode_changed(mode: int)
signal contacts_changed(count: int)

var mode: int = Mode.PASSIVE
var cooldown := 0.0
## Whether the sonar is pinging on its own. This is the toggle the player flips;
## `mode` is only what the HUD reports, and is derived from this and from whether
## a ring happens to be in flight.
var continuous := false
## How far a ping sweeps, extended by the refit bay. Defaults to the config
## number, which the radar maps to its own disc.
var max_range := GameConfig.SONAR_MAX_RANGE

## Fish -> remaining contact time. Keyed by node instance.
var contacts: Dictionary = {}

## Rings currently expanding, so the radar can draw the same circles the world
## does. More than one is normal: a continuous ping can have the previous ring
## still travelling when the next one launches.
var _rings: Array[SonarRing] = []

var _blip_at: Dictionary = {}
var _ping_origin := Vector2.ZERO
## Seeded off the world seed rather than thrown from the global dice, so where
## a ping sends a searching creature is a fixed decision you can reason about
## instead of a fresh one every dive.
var _rng := GameConfig.seeded_rng()


func _process(delta: float) -> void:
	# The cooldown always ticks down, whether or not the sonar is on, so
	# switching it off and straight back on cannot be used to bypass the wait.
	if cooldown > 0.0:
		cooldown = maxf(cooldown - delta, 0.0)

	if continuous and cooldown <= 0.0:
		ping()

	_prune_rings()
	_refresh_mode()

	var expired: Array = []
	for key in contacts.keys():
		var t: float = contacts[key] - delta
		if t <= 0.0:
			expired.append(key)
		else:
			contacts[key] = t
	if not expired.is_empty():
		for key in expired:
			contacts.erase(key)
		contacts_changed.emit(contacts.size())

	_passive_scan(delta)


func _passive_scan(_delta: float) -> void:
	var player := get_parent() as Node2D
	if player == null:
		return
	var now := float(Time.get_ticks_msec()) / 1000.0
	for node in get_tree().get_nodes_in_group(SeaEnemy.GROUP):
		var enemy := node as SeaEnemy
		if enemy == null or not is_instance_valid(enemy):
			_blip_at.erase(node)
			continue
		var dist := GameConfig.wrapped_delta(player.global_position, enemy.global_position).length()
		if dist <= GameConfig.SONAR_PROXIMITY_RADIUS:
			reveal(enemy, GameConfig.SONAR_CONTACT_DURATION)
		elif enemy.velocity.length() > GameConfig.SONAR_FAST_ENEMY_SPEED:
			reveal(enemy, GameConfig.SONAR_CONTACT_DURATION * 0.5)

		# Occasional unprompted blip, so idling is never fully safe. Only for
		# fish already within hydrophone range, otherwise every fish in the
		# world ticks a contact off on its own timer.
		if dist <= max_range:
			if not _blip_at.has(enemy) or now >= float(_blip_at[enemy]):
				_blip_at[enemy] = now + _rng.randf_range(GameConfig.SONAR_BLIP_MIN, GameConfig.SONAR_BLIP_MAX)
				reveal(enemy, GameConfig.SONAR_BLIP_DURATION)


## Tab / Sonar button. Flips continuous pinging on and off. Releasing the key
## does nothing: it is a toggle, not a hold.
func toggle() -> void:
	continuous = not continuous
	if continuous:
		# On cooldown from a previous ping? Then switching back on just waits
		# out the remainder rather than firing early.
		ping()
	_refresh_mode()


## Fires a ping if off cooldown. Returns whether one was actually emitted.
func ping() -> bool:
	if cooldown > 0.0:
		return false
	cooldown = GameConfig.SONAR_COOLDOWN

	# Your own ping, heard from the hull, so it is not panned or attenuated.
	AudioDirector.play(get_tree(), &"ping", GameConfig.VOL_PING)

	_ping_origin = global_position
	var ring := _build_ring()
	if ring == null:
		return false
	ring.reached.connect(_on_ring_reached)
	add_child(ring)
	_rings.append(ring)
	_refresh_mode()
	return true


## Radii of every ring in flight, for the radar to draw.
func active_ring_radii() -> Array[float]:
	var out: Array[float] = []
	for ring in _rings:
		if is_instance_valid(ring):
			out.append(ring.radius)
	return out


func _prune_rings() -> void:
	var live: Array[SonarRing] = []
	for ring in _rings:
		if is_instance_valid(ring):
			live.append(ring)
	_rings = live


## ACTIVE while continuous pinging is on or a ring is still travelling, so the
## button reads honestly whether the player is holding the sonar open or has
## just been kicked off it by the cooldown.
func _refresh_mode() -> void:
	var next := Mode.PASSIVE
	if continuous or not _rings.is_empty():
		next = Mode.ACTIVE
	if next != mode:
		mode = next
		mode_changed.emit(mode)


func _build_ring() -> SonarRing:
	var scene := load(RING_SCENE) as PackedScene
	if scene != null:
		var instance := scene.instantiate() as SonarRing
		if instance != null:
			instance.max_radius = max_range
			instance.speed = GameConfig.SONAR_PING_SPEED
			return instance
	push_error("Sonar: could not instantiate %s, falling back to bare ring." % RING_SCENE)
	var bare := SonarRing.new()
	bare.max_radius = max_range
	bare.speed = GameConfig.SONAR_PING_SPEED
	return bare


## A bigger array sweeps further. Called by the refit bay; the radar reads the
## same number, so the disc and the sweep never disagree.
func expand_range(new_range: float) -> void:
	if new_range <= max_range:
		return
	max_range = new_range


## A ping gives the enemy a bearing, not a target. Fish and crabs are only
## ever put on ALERT here, and the player position passed in is the ring's
## origin rather than where they actually are, so searching a pinged area
## does not walk straight to the hull.
##
## The creature is a SeaEnemy, so it is simply told. This used to ask
## `has_method("set_alert")` and then call the method by name, which is a guess
## dressed up as a check: every enemy has always had set_alert, and the only
## thing the guard could do was let a genuine mistake through silently.
func _on_ring_reached(enemy: SeaEnemy) -> void:
	if not is_instance_valid(enemy):
		return
	# Reefs occlude the ping: a reef between player and enemy hides the contact.
	if GameConfig.reef_between(get_world_2d().direct_space_state,
			_ping_origin, enemy.global_position):
		return
	reveal(enemy, GameConfig.SONAR_CONTACT_DURATION)
	# The fix is deliberately off the origin rather than on it — see
	# SONAR_PING_SEARCH_SPREAD — but off by less than the area it will search.
	var spread := Vector2.from_angle(_rng.randf() * TAU) * GameConfig.SONAR_PING_SEARCH_SPREAD
	# Folded back inside the water: the spread can carry the fix past an edge, and
	# an un-wrapped guess makes the search walk the long way round to reach it.
	enemy.set_alert(GameConfig.wrap_position(_ping_origin + spread))


func reveal(fish: SeaEnemy, duration: float) -> void:
	if fish == null or not is_instance_valid(fish):
		return
	var current: float = contacts.get(fish, 0.0)
	if duration <= current:
		return
	# A blip fires only on *new* acquisition. _passive_scan calls this every
	# frame for anything inside hydrophone range, so blipping per call would
	# machine-gun the speaker at 60Hz.
	if current <= 0.0:
		_play_blip(fish)
	contacts[fish] = duration
	contacts_changed.emit(contacts.size())


## One blip per acquisition, pitched to species and state so a contact you
## cannot see is still identifiable by ear. Both come straight off the creature
## now, instead of the state and species being re-derived from whatever object
## happened to arrive.
func _play_blip(enemy: SeaEnemy) -> void:
	var voice := enemy.profile()
	if voice == null:
		return
	AudioDirector.play_at(get_tree(), AudioDirector.blip_key(voice.id, enemy.state),
		enemy.global_position, GameConfig.VOL_BLIP)


func drop(fish: SeaEnemy) -> void:
	if contacts.has(fish):
		contacts.erase(fish)
		contacts_changed.emit(contacts.size())


func has_contact(fish: SeaEnemy) -> bool:
	return contacts.has(fish)


## Live contacts as enemies, skipping any that died since the last scan.
func contact_list() -> Array[SeaEnemy]:
	var out: Array[SeaEnemy] = []
	for key in contacts.keys():
		if is_instance_valid(key):
			out.append(key)
		else:
			contacts.erase(key)
	return out