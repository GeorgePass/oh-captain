class_name Reef
extends StaticBody2D
## Static circular-ish hazard. Blocks the player, stops torpedoes, and
## occludes sonar pings.

@export var radius := 70.0
@export var point_count := 9
## 0 = smooth circle, higher = spikier.
@export var jag := 0.35
@export var fill := Color(0.20, 0.42, 0.36)
@export var edge := Color(0.10, 0.24, 0.20)

var _points := PackedVector2Array()


func _ready() -> void:
	collision_layer = GameConfig.LAYER_REEF_BIT
	collision_mask = GameConfig.REEF_MASK
	z_index = -1
	_generate()
	_build_collision()
	queue_redraw()


func _generate() -> void:
	_points = PackedVector2Array()
	for i in maxi(3, point_count):
		var a := TAU * float(i) / float(maxi(3, point_count))
		var r := radius * (1.0 - jag * 0.5 + randf() * jag)
		_points.append(Vector2(cos(a), sin(a)) * r)


func _build_collision() -> void:
	var shape := CollisionPolygon2D.new()
	shape.polygon = _points
	add_child(shape)


func _draw() -> void:
	if _points.size() < 3:
		return
	draw_colored_polygon(_points, fill)
	draw_polyline(GameConfig.closed(_points), edge, 3.0, true)