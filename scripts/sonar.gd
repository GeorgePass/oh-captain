class_name Sonar
extends Node2D
## Owns sonar mode, ping cooldowns, and the live contact list.
##
## A "contact" is a revealed fish plus a decaying timer. Contacts feed the HUD
## radar, the lock-on logic, and the empty-contact cleanup that drops locks.

enum Mode { PASSIVE, ACTIVE }

const RING_SCENE := "res://scenes/sonar_ring.tscn"

signal mode_changed(mode: int)
signal contacts_changed(count: int)

var mode: int = Mode.PASSIVE
var cooldown := 0.0

## Fish -> remaining contact time. Keyed by node instance.
var contacts: Dictionary = {}

var _blip_at: Dictionary = {}
var _ping_origin := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	if cooldown > 0.0:
		cooldown = maxf(cooldown - delta, 0.0)

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


func _passive_scan(delta: float) -> void:
	var player := get_parent() as Node2D
	if player == null:
		return
	var now := float(Time.get_ticks_msec()) / 1000.0
	for node in get_tree().get_nodes_in_group(EnemyFish.GROUP):
		var fish := node as Node2D
		if fish == null or not is_instance_valid(fish):
			_blip_at.erase(node)
			continue
		var dist := player.global_position.distance_to(fish.global_position)
		if dist <= GameConfig.SONAR_PROXIMITY_RADIUS:
			reveal(fish, GameConfig.SONAR_CONTACT_DURATION)
		elif fish.velocity.length() > GameConfig.SONAR_FAST_ENEMY_SPEED:
			reveal(fish, GameConfig.SONAR_CONTACT_DURATION * 0.5)

		# Occasional unprompted blip, so idling is never fully safe.
		if not _blip_at.has(fish) or now >= float(_blip_at[fish]):
			_blip_at[fish] = now + _rng.randf_range(GameConfig.SONAR_BLIP_MIN, GameConfig.SONAR_BLIP_MAX)
			reveal(fish, GameConfig.SONAR_BLIP_DURATION)


func toggle() -> void:
	# Tab while ACTIVE drops back to passive; Tab while PASSIVE fires a ping.
	if mode == Mode.ACTIVE:
		mode = Mode.PASSIVE
		mode_changed.emit(mode)
		return
	ping()


## Fires a ping if off cooldown. Returns whether one was actually emitted.
func ping() -> bool:
	if cooldown > 0.0:
		return false
	cooldown = GameConfig.SONAR_COOLDOWN
	mode = Mode.ACTIVE
	mode_changed.emit(mode)

	_ping_origin = global_position
	var ring := _build_ring()
	if ring == null:
		return false
	ring.reached.connect(_on_ring_reached)
	add_child(ring)
	return true


func _build_ring() -> SonarRing:
	var scene := load(RING_SCENE) as PackedScene
	if scene != null:
		var instance := scene.instantiate() as SonarRing
		if instance != null:
			instance.max_radius = GameConfig.SONAR_MAX_RANGE
			instance.speed = GameConfig.SONAR_PING_SPEED
			return instance
	push_error("Sonar: could not instantiate %s, falling back to bare ring." % RING_SCENE)
	var bare := SonarRing.new()
	bare.max_radius = GameConfig.SONAR_MAX_RANGE
	bare.speed = GameConfig.SONAR_PING_SPEED
	return bare


func _on_ring_reached(fish: Node2D) -> void:
	if fish == null or not is_instance_valid(fish):
		return
	# Reefs occlude the ping: a reef between player and fish hides the contact.
	if _blocked_by_reef(_ping_origin, fish.global_position):
		return
	reveal(fish, GameConfig.SONAR_CONTACT_DURATION)
	if fish.has_method(&"set_hostile"):
		fish.call(&"set_hostile")


func _blocked_by_reef(from: Vector2, to: Vector2) -> bool:
	if from.is_equal_approx(to):
		return false
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to, GameConfig.LAYER_REEF_BIT)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not space.intersect_ray(query).is_empty()


func reveal(fish: Node2D, duration: float) -> void:
	if fish == null or not is_instance_valid(fish):
		return
	var current: float = contacts.get(fish, 0.0)
	if duration <= current:
		return
	contacts[fish] = duration
	contacts_changed.emit(contacts.size())


func drop(fish: Node2D) -> void:
	if contacts.has(fish):
		contacts.erase(fish)
		contacts_changed.emit(contacts.size())


func has_contact(fish: Node2D) -> bool:
	return contacts.has(fish)


## Live contacts as nodes, skipping any that died since the last scan.
func contact_list() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for key in contacts.keys():
		if is_instance_valid(key):
			out.append(key)
		else:
			contacts.erase(key)
	return out