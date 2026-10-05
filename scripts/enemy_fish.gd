class_name EnemyFish
extends CharacterBody2D
## Drifting fish that becomes hostile when provoked, then charges the player.

enum State { PASSIVE, HOSTILE }

const GROUP := "fish"

signal died(fish: Node2D)
signal hp_changed(hp: int, max_hp: int)

@export var max_hp := GameConfig.FISH_MAX_HP

var hp: int
var state: int = State.PASSIVE

var _wander_dir := Vector2.RIGHT
var _wander_timer := 0.0
## Seconds this fish has spent hearing the hull without breaking off.
var _alert_timer := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	hp = max_hp
	collision_layer = GameConfig.LAYER_ENEMY_BIT
	collision_mask = GameConfig.ENEMY_MASK
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	z_index = 0
	_wander_dir = Vector2.RIGHT.rotated(randf() * TAU)
	hp_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	if state == State.HOSTILE:
		_chase(delta)
	else:
		_drift(delta)
		_check_detection()
	move_and_slide()
	_wrap_world()
	queue_redraw()


func _drift(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(1.2, 3.0)
		_wander_dir = Vector2.RIGHT.rotated(randf() * TAU)
	velocity = velocity.lerp(_wander_dir * GameConfig.FISH_PASSIVE_SPEED, GameConfig.FISH_ACCEL * delta)
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
	velocity = velocity.lerp(to_player.normalized() * GameConfig.FISH_CHARGE_SPEED, GameConfig.FISH_ACCEL * delta)
	rotation = lerp_angle(rotation, velocity.angle(), GameConfig.FISH_TURN_RATE * delta)


## Stealth: a fish only hears the hull if it is close, unobstructed, and the
## player has been loud for a moment. Sprinting roughly doubles earshot, so
## going fast is the thing that gives you away, not simply existing.
func _check_detection() -> void:
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

	# Linger in the open and the fish works out something is there.
	_alert_timer += get_physics_process_delta_time()
	if _alert_timer >= GameConfig.FISH_ALERT_DELAY:
		set_hostile()


## Reefs between the hull and the fish muffle it, same as they block the ping.
func _muted_by_reef(player_pos: Vector2) -> bool:
	if global_position.is_equal_approx(player_pos):
		return false
	var query := PhysicsRayQueryParameters2D.create(
		global_position, player_pos, GameConfig.LAYER_REEF_BIT)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func set_hostile() -> void:
	if state == State.HOSTILE:
		return
	state = State.HOSTILE
	if velocity.length() < GameConfig.FISH_PASSIVE_SPEED:
		velocity = _wander_dir * GameConfig.FISH_PASSIVE_SPEED


func take_damage(amount: int) -> void:
	if hp <= 0:
		return
	hp -= amount
	hp_changed.emit(hp, max_hp)
	# Taking a hit always provokes a response.
	set_hostile()
	if hp <= 0:
		died.emit(self)
		queue_free()


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


func _draw() -> void:
	var hostile := state == State.HOSTILE
	var body := Color(0.85, 0.25, 0.22) if hostile else Color(0.32, 0.52, 0.72)
	var fin := Color(0.20, 0.32, 0.45) if not hostile else Color(0.55, 0.14, 0.12)
	var hull := PackedVector2Array([
		Vector2(16, 0), Vector2(-8, -8), Vector2(-3, 0), Vector2(-8, 8),
	])
	draw_colored_polygon(hull, body)
	draw_polyline(GameConfig.closed(hull), fin, 2.0, true)
	draw_circle(Vector2(8, 0), 2.2, Color(0.05, 0.05, 0.07))
	if hostile:
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 24, Color(0.95, 0.25, 0.2, 0.35), 2.0, true)