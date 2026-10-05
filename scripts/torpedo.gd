class_name Torpedo
extends CharacterBody2D
## Player-fired projectile. Homing only when something is locked at launch.

var damage := GameConfig.TORPEDO_DAMAGE
var lifetime := GameConfig.TORPEDO_LIFETIME
var speed := GameConfig.TORPEDO_SPEED
var homing_turn_rate := GameConfig.TORPEDO_TURN_RATE

## Locked target captured at launch. Null means the torpedo flies straight.
var target: Node2D = null

var _life_left := 0.0


func _ready() -> void:
	_life_left = lifetime
	collision_layer = GameConfig.LAYER_TORPEDO_BIT
	collision_mask = GameConfig.TORPEDO_MASK
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	z_index = 1
	queue_redraw()


func launch(from: Vector2, direction: Vector2) -> void:
	global_position = from
	velocity = direction.normalized() * speed
	rotation = velocity.angle()
	AudioDirector.play_at(get_tree(), &"torpedo_launch", from, GameConfig.VOL_TORPEDO)


func _physics_process(delta: float) -> void:
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()
		return
	_steer(delta)
	move_and_slide()
	_wrap_world()
	if _resolve_hits():
		return
	queue_redraw()


## Returns true when the torpedo has consumed its impact and should despawn.
func _resolve_hits() -> bool:
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider is SeaEnemy:
			(collider as SeaEnemy).take_damage(damage)
			# Wet, or a rock hit. Kept clearly different so a blind shot against
			# a reef is audible as a miss.
			_impact(&"torpedo_hit_flesh")
			return true
		if collider is Reef:
			_impact(&"torpedo_hit_reef")
			return true
	return false


func _impact(sound: StringName) -> void:
	var at := global_position
	var parent := get_parent()
	if parent != null:
		var blast := Blast.new()
		blast.global_position = at
		blast.z_index = 6
		parent.add_child(blast)
	AudioDirector.play_at(get_tree(), sound, at, GameConfig.VOL_TORPEDO)
	queue_free()


func _steer(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var desired := (target.global_position - global_position).angle()
	# Mild steering: enough to correct a moving target, not enough to snap.
	var step := homing_turn_rate * delta
	var current := velocity.angle()
	velocity = Vector2.from_angle(rotate_toward(current, desired, step)) * speed
	rotation = velocity.angle()


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
	var pts := PackedVector2Array([
		Vector2(9, 0), Vector2(-4, -3.5), Vector2(-4, 3.5),
	])
	draw_colored_polygon(pts, Color(0.95, 0.97, 1.0))
	draw_arc(Vector2(-4, 0), 3.5, -PI * 0.5, PI * 0.5, 8, Color(0.4, 0.9, 1.0, 0.7), 1.5, true)