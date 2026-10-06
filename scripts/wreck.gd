class_name Wreck
extends Node2D
## Decorative sunken hull. Visual only for v1 - no collision, no loot.


@export var length := 120.0
@export var beam := 34.0
@export var tilt := 0.0
## Marked as the harbourmaster's errand site. Painted with a teal hull and a
## cargo crate on the deck, so the wreck the radar pins and the wreck you swim
## to are recognisably the same place.
@export var mission_site := false


func _ready() -> void:
	z_index = -2
	queue_redraw()


func _draw() -> void:
	var h := length * 0.5
	var b := beam * 0.5
	var hull := PackedVector2Array([
		Vector2(-h, -b * 0.7),
		Vector2(h * 0.55, -b),
		Vector2(h, 0.0),
		Vector2(h * 0.55, b),
		Vector2(-h, b * 0.7),
	])
	if mission_site:
		draw_colored_polygon(hull, Color(0.20, 0.33, 0.37, 0.95))
		draw_polyline(GameConfig.closed(hull), Color(0.42, 0.75, 0.80, 0.95), 2.0, true)
		# The crate that marks this one out from the other twenty-one wrecks.
		var crate := Vector2(0.0, -b * 0.4)
		draw_rect(Rect2(crate + Vector2(-7.0, -7.0), Vector2(14.0, 14.0)), Color(0.72, 0.60, 0.40))
		draw_line(crate + Vector2(-4.0, -4.0), crate + Vector2(4.0, 4.0), Color(0.35, 0.26, 0.14), 2.0)
		draw_line(crate + Vector2(4.0, -4.0), crate + Vector2(-4.0, 4.0), Color(0.35, 0.26, 0.14), 2.0)
		return
	draw_colored_polygon(hull, Color(0.26, 0.25, 0.29, 0.9))
	draw_polyline(GameConfig.closed(hull), Color(0.44, 0.43, 0.48, 0.9), 2.0, true)
	# keel line + snapped mast, to read as a wreck at a glance.
	draw_line(Vector2(-h * 0.8, 0.0), Vector2(h * 0.8, 0.0), Color(0.15, 0.14, 0.17, 0.8), 3.0)
	var mast := Vector2(h * 0.1, -b * 2.2)
	draw_line(Vector2(h * 0.1, -b), mast, Color(0.34, 0.32, 0.37, 0.9), 4.0)
	draw_line(mast, mast + Vector2(6.0, 14.0), Color(0.34, 0.32, 0.37, 0.7), 3.0)