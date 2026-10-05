class_name SonarRing
extends Area2D
## A single expanding sonar ping.
##
## The ring's Area2D body is synced to the growing radius so the ping is a real
## Area2D, but detection is resolved explicitly in `_scan()` rather than via
## area_entered. Overlap signals cannot tell you *when along the edge* an enemy
## was crossed, and we need the crossing frame to run the reef line-of-sight
## test.

signal reached(enemy: Node2D)

var radius := 0.0
var max_radius := GameConfig.SONAR_MAX_RANGE
var speed := GameConfig.SONAR_PING_SPEED
var origin := Vector2.ZERO
var tint := Color(0.35, 0.95, 0.85)

var _shape: CollisionShape2D


func _ready() -> void:
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0
	z_index = 5
	origin = global_position
	_shape = get_node_or_null("RingShape") as CollisionShape2D
	queue_redraw()


func _physics_process(delta: float) -> void:
	var prev := radius
	radius = minf(radius + speed * delta, max_radius)
	if radius > 0.0:
		_scan(prev, radius)
	_sync_shape()
	queue_redraw()
	if radius >= max_radius:
		queue_free()


## Emits `reached` for every fish the expanding edge swept past this frame.
func _scan(prev: float, now: float) -> void:
	for node in get_tree().get_nodes_in_group(SeaEnemy.GROUP):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var d := origin.distance_to(enemy.global_position)
		# Only fire on the frame the edge crosses this distance.
		if d > prev and d <= now:
			reached.emit(enemy)


func _sync_shape() -> void:
	if _shape == null:
		return
	var circle := _shape.shape as CircleShape2D
	if circle == null:
		return
	if circle.radius != radius:
		circle.radius = radius


func _draw() -> void:
	if radius <= 1.0:
		return
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, tint, 2.5, true)
	var inner := tint
	inner.a = 0.22
	draw_arc(Vector2.ZERO, radius * 0.94, 0.0, TAU, 96, inner, 1.5, true)