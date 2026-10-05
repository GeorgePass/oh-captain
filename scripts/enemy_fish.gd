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


func _draw() -> void:
	var hostile := is_hostile()
	var body := Color(0.85, 0.25, 0.22) if hostile else Color(0.32, 0.52, 0.72)
	if is_alert():
		# Amber while it is still looking, so a searching fish is readable
		# as searching rather than as a confirmed threat.
		body = Color(0.85, 0.66, 0.24)
	var fin := Color(0.20, 0.32, 0.45) if not hostile else Color(0.55, 0.14, 0.12)
	if is_alert():
		fin = Color(0.46, 0.34, 0.12)
	var hull := PackedVector2Array([
		Vector2(16, 0), Vector2(-8, -8), Vector2(-3, 0), Vector2(-8, 8),
	])
	draw_colored_polygon(hull, body)
	draw_polyline(GameConfig.closed(hull), fin, 2.0, true)
	draw_circle(Vector2(8, 0), 2.2, Color(0.05, 0.05, 0.07))
	if hostile:
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 24, Color(0.95, 0.25, 0.2, 0.35), 2.0, true)
	elif is_alert():
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 24, Color(0.95, 0.72, 0.25, 0.30), 1.6, true)
