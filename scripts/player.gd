class_name Player
extends CharacterBody2D
## Captain's boat: inertial steering, contact damage, wrap-around edges.

const GROUP := "player"
const TORPEDO_SCENE := "res://scenes/torpedo.tscn"

signal hp_changed(hp: int, max_hp: int)
signal ammo_changed(ammo: int, ammo_max: int)
signal gold_changed(gold: int)
signal fire_state_changed()
signal lock_changed(target: Node2D)
signal died(player: Node2D)

@export var max_hp := GameConfig.PLAYER_MAX_HP
@export var max_ammo := GameConfig.PLAYER_MAX_AMMO

var hp: int
var ammo: int
## Salvage collected. Survives nothing right now: dying ends the run.
var gold := 0
var locked_target: Node2D = null
var fire_cooldown := 0.0

## Enemies eligible for lock-on, rebuilt every physics frame, nearest first.
var _lockable: Array[Node2D] = []
## Targets Q has already walked through on the current pass.
var _lock_cycle: Array[Node2D] = []

var _sonar: Sonar
var _damage_cooldown := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	hp = max_hp
	ammo = max_ammo
	collision_layer = GameConfig.LAYER_PLAYER_BIT
	collision_mask = GameConfig.PLAYER_MASK
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	z_index = 2
	_sonar = get_node_or_null("Sonar") as Sonar
	# The camera rides on the hull, so it follows for free and survives the
	# world-wrap teleport without needing its position corrected.
	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.make_current()
	hp_changed.emit(hp, max_hp)
	ammo_changed.emit(ammo, max_ammo)
	gold_changed.emit(gold)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if fire_cooldown > 0.0:
		fire_cooldown = maxf(fire_cooldown - delta, 0.0)
	if _damage_cooldown > 0.0:
		_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)

	_refresh_lockable()
	_validate_lock()
	_read_input(delta)
	move_and_slide()
	_resolve_contact_damage()
	_wrap_world()
	queue_redraw()


## Discrete actions are handled from _input rather than polled in
## _physics_process or routed through _unhandled_input:
##   - _input runs before GUI dispatch, so Tab still arrives even though it is
##     the built-in ui_focus_next and the HUD would otherwise swallow it.
##   - event-based edges are not sampled once per physics frame, so a quick tap
##     can never fall between two frames and get dropped.
func _input(event: InputEvent) -> void:
	if hp <= 0 or not event.is_pressed() or event.is_echo():
		return
	if event.is_action("toggle_sonar"):
		toggle_sonar()
	elif event.is_action("cycle_lock"):
		cycle_lock()
	elif event.is_action("fire"):
		fire()


func _read_input(delta: float) -> void:
	# Turning is direct and thrust is inertial, so the hull carries its momentum
	# through a turn instead of pivoting on the spot.
	if Input.is_action_pressed("turn_left"):
		rotation -= GameConfig.PLAYER_TURN_RATE * delta
	if Input.is_action_pressed("turn_right"):
		rotation += GameConfig.PLAYER_TURN_RATE * delta

	var forward := Vector2.RIGHT.rotated(rotation)
	if Input.is_action_pressed("thrust"):
		velocity += forward * GameConfig.PLAYER_THRUST * delta
	elif Input.is_action_pressed("reverse"):
		velocity -= forward * GameConfig.PLAYER_REVERSE_THRUST * delta

	# Passive drag doubles as engine braking, and it applies whether or not the
	# screw is turning: a flat deceleration the whole way down, rather than an
	# exponential tail still trickling along ten seconds after you let go.
	velocity = velocity.move_toward(Vector2.ZERO, GameConfig.PLAYER_DECEL * delta)
	# The hull's ceiling, in either direction.
	velocity = velocity.limit_length(GameConfig.PLAYER_MAX_SPEED)


func _resolve_contact_damage() -> void:
	if _damage_cooldown > 0.0:
		return
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider is SeaEnemy:
			var enemy := collider as SeaEnemy
			# One that is running away is not fighting, so bumping into it costs
			# nothing. Chasing it down should not also be a punishment.
			if enemy.is_fleeing():
				return
			# Each species carries its own contact damage, so a crab hit hurts
			# far more than a fish brushing past.
			take_damage(enemy.contact_damage)
			# Knocked back a little, so a committed enemy cannot grind the hull
			# down by riding it.
			velocity = (global_position - enemy.global_position).normalized() \
				* GameConfig.CONTACT_KNOCKBACK + velocity * 0.3
			_damage_cooldown = GameConfig.CONTACT_DMG_COOLDOWN
			return
		if collider is Reef:
			take_damage(GameConfig.REEF_CONTACT_DMG)
			# Bounce off and bleed some speed so the hull does not grind.
			velocity = velocity.bounce(get_slide_collision(i).get_normal()) * 0.45
			_damage_cooldown = GameConfig.CONTACT_DMG_COOLDOWN
			return


func take_damage(amount: int) -> void:
	if hp <= 0:
		return
	hp = maxi(hp - amount, 0)
	hp_changed.emit(hp, max_hp)
	_flash(Color(1.7, 0.55, 0.5))
	# Non-positional: this is the hull being hit, so it comes from the hull.
	AudioDirector.play(get_tree(), &"damage", GameConfig.VOL_DAMAGE)
	if hp <= 0:
		died.emit(self)


func _flash(color: Color) -> void:
	modulate = color
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.22)


func _wrap_world() -> void:
	global_position = GameConfig.wrap_position(global_position)


# --- Sonar / lock ------------------------------------------------------------

func sonar() -> Sonar:
	return _sonar


func can_fire() -> bool:
	return hp > 0 and ammo > 0 and fire_cooldown <= 0.0


func add_gold(amount: int) -> void:
	if amount <= 0 or hp <= 0:
		return
	gold += amount
	gold_changed.emit(gold)


## Clamped to max_ammo, so a crate cannot push the player over the cap.
func add_ammo(amount: int) -> void:
	if amount <= 0 or hp <= 0:
		return
	ammo = mini(ammo + amount, max_ammo)
	ammo_changed.emit(ammo, max_ammo)
	fire_state_changed.emit()


func fire() -> Torpedo:
	if not can_fire():
		return null
	var direction := Vector2.RIGHT.rotated(rotation)
	var torpedo := _spawn_torpedo()
	if torpedo == null:
		return null
	# Capture the lock at launch so the torpedo commits to that target. The
	# target may have been freed since the lock was taken (killed by an earlier
	# torpedo, say), and assigning a freed object to a typed property is a hard
	# error, so re-check validity here rather than trusting the lock.
	if is_instance_valid(locked_target):
		torpedo.target = locked_target
	torpedo.launch(global_position + direction * GameConfig.TORPEDO_SPAWN_OFFSET, direction)

	# Only bill the shot once it actually exists.
	ammo -= 1
	fire_cooldown = GameConfig.FIRE_COOLDOWN
	ammo_changed.emit(ammo, max_ammo)
	fire_state_changed.emit()
	return torpedo


func _spawn_torpedo() -> Torpedo:
	var scene := load(TORPEDO_SCENE) as PackedScene
	if scene != null:
		var instance := scene.instantiate() as Torpedo
		if instance != null:
			get_parent().add_child(instance)
			return instance
	push_error("Player: could not instantiate %s" % TORPEDO_SCENE)
	return null


func toggle_sonar() -> void:
	if _sonar != null:
		_sonar.toggle()


func request_ping() -> void:
	if _sonar != null:
		_sonar.ping()


## Q / Lock button: walks the lockable set nearest-first without ever offering
## the same target twice in one pass, then starts a fresh pass from whoever is
## closest at that moment. In practice you tap Q and the lock walks outward from
## the hull, so a whole cluster can be surveyed in a couple of seconds instead of
## re-reading the same near fish every time.
func cycle_lock() -> void:
	var list := lockable()
	if list.is_empty():
		clear_lock()
		_lock_cycle.clear()
		return

	# Prune the pass. A target that has died or slipped out of range should not
	# keep a slot reserved, or the walk stalls waiting on something gone.
	var walked: Array[Node2D] = []
	for node in _lock_cycle:
		if is_instance_valid(node) and list.has(node):
			walked.append(node)

	# Whatever has not been offered yet. `list` is already sorted nearest-first.
	var fresh: Array[Node2D] = []
	for node in list:
		if not walked.has(node):
			fresh.append(node)

	# Everything lockable has been through: start again from the closest.
	if fresh.is_empty():
		walked.clear()
		fresh = list

	var pick := fresh[0]
	walked.append(pick)
	_lock_cycle = walked
	set_lock(pick)


## Everything eligible for lock-on right now, recomputed once per physics frame
## by `_refresh_lockable`. Sorted nearest-first, which is the order Q cycles in.
func lockable() -> Array[Node2D]:
	return _lockable


## Decides who can be locked, and writes the answer onto each enemy so the world
## can draw the right marker without asking back.
##
## Three ways to qualify, in order of how much they cost the enemy:
##   1. Inside visual range. Plain distance, no line-of-sight test.
##   2. On a sonar contact, at any distance. This is the whole payoff of pinging.
##   3. Inside visual range plus a margin, holding an eight second grace window
##      that keeps draining once that band is cleared, so a target which slips
##      out of sight is not lost on the frame it happens.
## Past three times visual range nothing is held by the window at all.
func _refresh_lockable() -> void:
	var out: Array[Node2D] = []
	var visual := GameConfig.LOCK_VISUAL_RANGE
	var band := visual + GameConfig.LOCK_RELEASE_MARGIN
	var hard := visual * GameConfig.LOCK_RELEASE_HARD_MULT

	for node in get_tree().get_nodes_in_group(SeaEnemy.GROUP):
		var enemy := node as SeaEnemy
		if enemy == null or not is_instance_valid(enemy):
			continue
		var d := global_position.distance_to(enemy.global_position)
		var on_sonar := _sonar != null and _sonar.has_contact(enemy)

		# The margin makes the edge of sight forgiving: an enemy has to actually
		# clear visual range plus the margin before the grace clock starts, so
		# drifting along the boundary neither drops the lock nor flickers it.
		var eligible := true
		if d <= band or on_sonar:
			enemy.set_lock_grace(GameConfig.LOCK_RELEASE_TIME)
		elif d <= hard:
			# Out of sight, but the window is still holding the lock.
			eligible = enemy.lock_grace_left() > 0.0
		else:
			# Genuinely gone. The window is not allowed to stretch this far.
			enemy.set_lock_grace(0.0)
			eligible = false

		enemy.lockable = eligible
		if eligible:
			out.append(enemy)

	out.sort_custom(_by_distance)
	_lockable = out


func contacts() -> Array[SeaEnemy]:
	if _sonar == null:
		return [] as Array[SeaEnemy]
	return _sonar.contact_list()


func set_lock(target: Node2D) -> void:
	# Validity has to be checked before anything else touches the old target, and
	# in particular before `is`: running `is` against a freed instance is itself a
	# runtime error, which is exactly what happens when a torpedo kills the fish
	# you have locked and the lock is dropped a frame later.
	if is_instance_valid(locked_target):
		if locked_target == target:
			return
		# Clear the outgoing bracket here rather than in a later sweep, so the
		# mark never outlives the lock by a frame.
		if locked_target is SeaEnemy:
			(locked_target as SeaEnemy).locked = false
	locked_target = target
	lock_changed.emit(locked_target)


func clear_lock() -> void:
	set_lock(null)


## Drops the lock if its target has been freed or is no longer eligible, and
## publishes the bracket on whoever is held. Runs after `_refresh_lockable`, so
## eligibility is this frame's rather than last frame's.
##
## A fish killed by a torpedo lingers as a freed object until the end of the
## frame, and one that swims out of sight is kept alive by the grace window
## inside `_refresh_lockable` rather than being lost on the frame it happens.
func _validate_lock() -> void:
	if locked_target == null:
		return
	if not is_instance_valid(locked_target) or not _lockable.has(locked_target):
		clear_lock()
		return
	(locked_target as SeaEnemy).locked = true


func _by_distance(a: Node2D, b: Node2D) -> bool:
	return global_position.distance_squared_to(a.global_position) \
		< global_position.distance_squared_to(b.global_position)


func _draw() -> void:
	var hull := PackedVector2Array([
		Vector2(20, 0), Vector2(-11, -11), Vector2(-4, 0), Vector2(-11, 11),
	])
	draw_colored_polygon(hull, Color(0.95, 0.84, 0.42))
	draw_polyline(GameConfig.closed(hull), Color(0.24, 0.19, 0.09), 2.0, true)
	# Facing pip, so heading reads clearly even in dense clutter.
	draw_circle(Vector2(8, 0), 2.6, Color(0.18, 0.14, 0.06))
	if velocity.length() > GameConfig.FAST_SPEED:
		draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 28, Color(1.0, 0.75, 0.35, 0.35), 1.5, true)