class_name EnemyFish
extends SeaEnemy
## Nimble, fragile fish. Quick to commit and hard to shake once it has seen
## you, but one torpedo and one bump is all it is worth.

func _init() -> void:
	max_hp = GameConfig.FISH_MAX_HP
	passive_speed = GameConfig.ENEMY_PASSIVE_SPEED
	charge_speed = GameConfig.FISH_CHARGE_SPEED
	turn_rate = GameConfig.ENEMY_TURN_RATE
	accel = GameConfig.ENEMY_ACCEL
	contact_damage = GameConfig.FISH_CONTACT_DMG
	gold_min = GameConfig.FISH_GOLD_MIN
	gold_max = GameConfig.FISH_GOLD_MAX


func species() -> StringName:
	return &"fish"


func _draw() -> void:
	var body := Color(0.32, 0.52, 0.72)
	var fin := Color(0.20, 0.32, 0.45)
	if is_hostile():
		body = Color(0.85, 0.25, 0.22)
		fin = Color(0.55, 0.14, 0.12)
	elif is_alert():
		# Amber while it is still looking, so a searching fish is readable
		# as searching rather than as a confirmed threat.
		body = Color(0.85, 0.66, 0.24)
		fin = Color(0.46, 0.34, 0.12)
	elif is_fleeing():
		# Pale and washed out: it is leaving, not fighting.
		body = Color(0.52, 0.80, 0.70)
		fin = Color(0.26, 0.44, 0.40)
	var hull := PackedVector2Array([
		Vector2(16, 0), Vector2(-8, -8), Vector2(-3, 0), Vector2(-8, 8),
	])
	draw_colored_polygon(hull, body)
	draw_polyline(GameConfig.closed(hull), fin, 2.0, true)
	draw_circle(Vector2(8, 0), 2.2, Color(0.05, 0.05, 0.07))
	if is_fleeing():
		# Motion lines off the tail, so it reads as running rather than merely
		# being a different colour.
		for i in 2:
			var x := -12.0 - float(i) * 6.0
			draw_line(Vector2(x, -4.0), Vector2(x - 7.0, -4.0), fin, 1.6)
			draw_line(Vector2(x, 4.0), Vector2(x - 7.0, 4.0), fin, 1.6)
	elif is_hostile():
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 24, Color(0.95, 0.25, 0.2, 0.35), 2.0, true)
	elif is_alert():
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 24, Color(0.95, 0.72, 0.25, 0.30), 1.6, true)
	_draw_lock_marker(16.0)
