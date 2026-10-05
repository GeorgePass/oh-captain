class_name EnemyCrab
extends SeaEnemy
## Armoured, slow hunter. Charges well under the hull's top speed so it can
## always be shaken off, but it soaks three torpedoes and a single hit hurts
## far more than a fish. The threat is that you cannot simply outrun it and
## forget about it.

func species() -> StringName:
	return &"crab"


func _init() -> void:
	max_hp = GameConfig.CRAB_MAX_HP
	passive_speed = GameConfig.CRAB_PASSIVE_SPEED
	charge_speed = GameConfig.CRAB_CHARGE_SPEED
	turn_rate = GameConfig.CRAB_TURN_RATE
	accel = GameConfig.CRAB_ACCEL
	contact_damage = GameConfig.CRAB_CONTACT_DMG
	gold_min = GameConfig.CRAB_GOLD_MIN
	gold_max = GameConfig.CRAB_GOLD_MAX


## Broad, low shell with a squared carapace and two raised claws, so the
## silhouette is nothing like the dart shape of a fish.
func _draw() -> void:
	var shell := Color(0.42, 0.44, 0.40)
	var edge := Color(0.22, 0.24, 0.22)
	var claw := Color(0.52, 0.54, 0.50)
	if is_hostile():
		shell = Color(0.62, 0.30, 0.24)
		edge = Color(0.26, 0.13, 0.10)
		claw = Color(0.72, 0.38, 0.28)
	elif is_alert():
		shell = Color(0.60, 0.47, 0.26)
		edge = Color(0.32, 0.24, 0.11)
		claw = Color(0.70, 0.57, 0.32)
	elif is_fleeing():
		# Pale and washed out: it is leaving, not fighting.
		shell = Color(0.50, 0.72, 0.64)
		edge = Color(0.24, 0.40, 0.36)
		claw = Color(0.58, 0.78, 0.70)

	var body := PackedVector2Array([
		Vector2(14, -16), Vector2(-14, -14), Vector2(-18, 0),
		Vector2(-14, 14), Vector2(14, 16),
	])
	draw_colored_polygon(body, shell)
	draw_polyline(GameConfig.closed(body), edge, 2.5, true)
	# Shell ridge and segment lines.
	draw_line(Vector2(-16, 0), Vector2(12, 0), edge, 1.6)
	for y in [-8.0, 8.0]:
		draw_line(Vector2(-10, y), Vector2(8, y * 1.25), edge, 1.2)

	# Claws, forward of the shell.
	for side in [-1.0, 1.0]:
		draw_line(Vector2(10, side * 12), Vector2(24, side * 17), claw, 3.5)
		draw_circle(Vector2(26, side * 18), 4.5, claw)
		draw_arc(Vector2(26, side * 18), 4.5, 0.0, TAU, 10, edge, 1.4, true)
	# Legs.
	for i in 3:
		var x := 4.0 - float(i) * 8.0
		for side in [-1.0, 1.0]:
			draw_line(Vector2(x, side * 13), Vector2(x - 3, side * 22), edge, 2.0)

	# Eyes on stalks, because a crab without them reads as a rock.
	draw_circle(Vector2(9, -5), 2.2, Color(0.05, 0.05, 0.07))
	draw_circle(Vector2(9, 5), 2.2, Color(0.05, 0.05, 0.07))

	if is_fleeing():
		# Legs held wide and trailing, so it reads as backing off.
		draw_line(Vector2(-22.0, -10.0), Vector2(-30.0, -15.0), edge, 2.0)
		draw_line(Vector2(-22.0, 10.0), Vector2(-30.0, 15.0), edge, 2.0)
	elif is_hostile():
		draw_arc(Vector2.ZERO, 32.0, 0.0, TAU, 28, Color(0.95, 0.25, 0.2, 0.35), 2.5, true)
	elif is_alert():
		draw_arc(Vector2.ZERO, 32.0, 0.0, TAU, 28, Color(0.95, 0.72, 0.25, 0.28), 2.0, true)
	_draw_lock_marker(20.0)
