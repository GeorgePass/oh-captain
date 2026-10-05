class_name Player
extends CharacterBody2D
## Captain's boat: inertial steering, contact damage, wrap-around edges.

const GROUP := "player"
const TORPEDO_SCENE := "res://scenes/torpedo.tscn"

signal hp_changed(hp: int, max_hp: int)
signal ammo_changed(ammo: int, ammo_max: int)
signal fire_state_changed()
signal lock_changed(target: Node2D)
signal died(player: Node2D)

@export var max_hp := GameConfig.PLAYER_MAX_HP
@export var max_ammo := GameConfig.PLAYER_MAX_AMMO

var hp: int
var ammo: int
var locked_target: Node2D = null
var fire_cooldown := 0.0

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
	if _sonar != null:
		_sonar.contacts_changed.connect(_on_contacts_changed)
	hp_changed.emit(hp, max_hp)
	ammo_changed.emit(ammo, max_ammo)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if fire_cooldown > 0.0:
		fire_cooldown = maxf(fire_cooldown - delta, 0.0)
	if _damage_cooldown > 0.0:
		_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)

	_read_discrete_input()
	_read_input(delta)
	move_and_slide()
	_resolve_contact_damage()
	_wrap_world()
	queue_redraw()


## Sonar / lock / fire are polled rather than handled in _unhandled_input:
## Tab is Godot's built-in ui_focus_next, so the GUI can consume the key event
## before an unhandled-input handler ever sees it.
func _read_discrete_input() -> void:
	if hp <= 0:
		return
	if Input.is_action_just_pressed("toggle_sonar"):
		toggle_sonar()
	if Input.is_action_just_pressed("cycle_lock"):
		cycle_lock()
	if Input.is_action_just_pressed("fire"):
		fire()


func _read_input(delta: float) -> void:
	# Turning is direct, thrust is inertial: you can only turn while moving.
	if Input.is_action_pressed("turn_left"):
		rotation -= GameConfig.PLAYER_TURN_RATE * delta
	if Input.is_action_pressed("turn_right"):
		rotation += GameConfig.PLAYER_TURN_RATE * delta

	var forward := Vector2.RIGHT.rotated(rotation)
	if Input.is_action_pressed("thrust"):
		velocity += forward * GameConfig.PLAYER_THRUST * delta
	elif Input.is_action_pressed("reverse"):
		velocity -= forward * GameConfig.PLAYER_REVERSE_THRUST * delta

	# Passive drag doubles as engine braking.
	velocity = velocity.move_toward(Vector2.ZERO, GameConfig.PLAYER_DRAG * 120.0 * delta)
	if velocity.length() > GameConfig.PLAYER_MAX_SPEED:
		velocity = velocity.normalized() * GameConfig.PLAYER_MAX_SPEED


func _resolve_contact_damage() -> void:
	if _damage_cooldown > 0.0:
		return
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider is EnemyFish:
			take_damage(GameConfig.ENEMY_CONTACT_DMG)
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
	if hp <= 0:
		died.emit(self)


func _flash(color: Color) -> void:
	modulate = color
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.22)


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


# --- Sonar / lock ------------------------------------------------------------

func sonar() -> Sonar:
	return _sonar


func can_fire() -> bool:
	return hp > 0 and ammo > 0 and fire_cooldown <= 0.0


func fire() -> Torpedo:
	if not can_fire():
		return null
	var direction := Vector2.RIGHT.rotated(rotation)
	var torpedo := _spawn_torpedo()
	if torpedo == null:
		return null
	# Capture the lock at launch so the torpedo commits to that target.
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


## Q / Lock button: cycles contacts by distance. A single contact auto-locks.
func cycle_lock() -> void:
	var list := contacts()
	if list.is_empty():
		clear_lock()
		return

	if list.size() == 1:
		set_lock(list[0])
		return

	var ordered := list.duplicate()
	ordered.sort_custom(_by_distance)

	var index := ordered.find(locked_target)
	if index < 0:
		# Stale or cleared lock: start at the nearest contact.
		set_lock(ordered[0])
	else:
		set_lock(ordered[(index + 1) % ordered.size()])


func contacts() -> Array[Node2D]:
	if _sonar == null:
		return [] as Array[Node2D]
	return _sonar.contact_list()


func set_lock(target: Node2D) -> void:
	if locked_target == target:
		return
	locked_target = target
	lock_changed.emit(locked_target)


func clear_lock() -> void:
	set_lock(null)


func _by_distance(a: Node2D, b: Node2D) -> bool:
	return global_position.distance_squared_to(a.global_position) \
		< global_position.distance_squared_to(b.global_position)


func _on_contacts_changed(_count: int) -> void:
	# A single contact auto-locks. Anything else keeps whatever lock is held,
	# and an invalid or no-longer-revealed lock falls away.
	if locked_target != null and not is_instance_valid(locked_target):
		clear_lock()
		return
	var list := contacts()
	if list.size() == 1:
		set_lock(list[0])
	elif locked_target != null and not list.has(locked_target):
		clear_lock()


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