class_name Blast
extends Node2D
## Short-lived expanding ring used as cheap hit/impact feedback.

var duration := 0.35
var radius := 22.0
var tint := Color(1.0, 0.72, 0.32)

var _t := 0.0


func _ready() -> void:
	z_index = 4


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= duration:
		queue_free()


func _draw() -> void:
	var k := clampf(_t / maxf(duration, 0.001), 0.0, 1.0)
	var c := tint
	c.a = 1.0 - k
	draw_arc(Vector2.ZERO, radius * (0.25 + k * 1.1), 0.0, TAU, 32, c, 1.0 + 3.0 * (1.0 - k), true)