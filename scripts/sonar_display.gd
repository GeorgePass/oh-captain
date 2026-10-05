extends Control
## Circular radar: player at centre with a facing tick, revealed fish as red
## dots, and a ring + bracket on the locked target.

const PLAYER_COLOR := Color(0.95, 0.84, 0.42)
## Unknown or merely drifting.
const CONTACT_COLOR := Color(0.42, 0.72, 0.88)
## Searching: something was heard, nothing seen.
const ALERT_COLOR := Color(0.95, 0.72, 0.25)
## Has the hull in sight.
const HOSTILE_COLOR := Color(0.92, 0.26, 0.22)
## Broken and running for it.
const FLEEING_COLOR := Color(0.52, 0.80, 0.70)
const LOCK_COLOR := Color(1.0, 0.86, 0.35)
const BEAM_COLOR := Color(1.0, 0.86, 0.35, 0.28)
const RANGE_COLOR := Color(0.30, 0.82, 0.78, 0.85)
const BG_COLOR := Color(0.03, 0.11, 0.14, 0.55)
## Matches the ping's tint in the world, so the radar circle and the one you
## can see through the hull read as the same event.
const PING_COLOR := Color(0.35, 0.95, 0.85)

@onready var range_label: Label = $RangeLabel

var player: Player


func _ready() -> void:
	resized.connect(queue_redraw)


func _radius() -> float:
	return minf(size.x, size.y) * 0.5 - 6.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := _radius()

	draw_circle(center, radius, BG_COLOR)
	# Range rings, with the outer one marking true sonar range.
	draw_arc(center, radius, 0.0, TAU, 72, RANGE_COLOR, 2.0, true)
	draw_arc(center, radius * 0.66, 0.0, TAU, 56, Color(RANGE_COLOR.r, RANGE_COLOR.g, RANGE_COLOR.b, 0.25), 1.0, true)
	draw_arc(center, radius * 0.33, 0.0, TAU, 40, Color(RANGE_COLOR.r, RANGE_COLOR.g, RANGE_COLOR.b, 0.25), 1.0, true)
	draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), Color(RANGE_COLOR.r, RANGE_COLOR.g, RANGE_COLOR.b, 0.18), 1.0)
	draw_line(center - Vector2(0, radius), center + Vector2(0, radius), Color(RANGE_COLOR.r, RANGE_COLOR.g, RANGE_COLOR.b, 0.18), 1.0)

	if player == null or not is_instance_valid(player):
		return

	# `scale` is a Control property; shadowing it raises a warning.
	var scale := radius / GameConfig.SONAR_MAX_RANGE
	var contacts := player.contacts()
	var locked := player.locked_target

	# The ping wavefront itself, so the radar shows what is sweeping outward
	# rather than only where it has already landed. Drawn under the contacts so
	# a blip is never hidden behind a ring that happens to be passing over it.
	var sonar := player.sonar()
	if sonar != null:
		for ring_radius in sonar.active_ring_radii():
			if ring_radius <= 1.0:
				continue
			var px := minf(ring_radius * scale, radius)
			draw_arc(center, px, 0.0, TAU, 72, PING_COLOR, 2.0, true)
			var wash := PING_COLOR
			wash.a = 0.16
			draw_arc(center, px * 0.96, 0.0, TAU, 64, wash, 5.0, true)

	for contact in contacts:
		if not is_instance_valid(contact):
			continue
		var rel := (contact.global_position - player.global_position) * scale
		# Clamp instead of cull: a contact beyond range still hugs the rim.
		if rel.length() > radius - 5.0:
			rel = rel.normalized() * (radius - 5.0)
		var dot := center + rel
		# Same three colours the creatures themselves are drawn in, so the
		# radar state and the world state agree.
		var tint := CONTACT_COLOR
		if contact is SeaEnemy:
			var enemy := contact as SeaEnemy
			if enemy.is_fleeing():
				tint = FLEEING_COLOR
			elif enemy.is_hostile():
				tint = HOSTILE_COLOR
			elif enemy.is_alert():
				tint = ALERT_COLOR
			if contact is EnemyCrab:
				# Crabs get a ring so they read as heavier at a glance.
				draw_arc(dot, 7.5, 0.0, TAU, 14, tint.darkened(0.2), 1.6, true)
		draw_circle(dot, 4.5, tint)

		if contact == locked:
			draw_line(center, dot, BEAM_COLOR, 1.0)
			draw_arc(dot, 10.0, 0.0, TAU, 24, LOCK_COLOR, 2.0, true)
			# Corner ticks read as a reticle even at small sizes.
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				draw_line(dot + corner * 10.0, dot + corner * 14.0, LOCK_COLOR, 1.5)

	# Player mark: hull dot plus a heading tick.
	draw_circle(center, 5.5, PLAYER_COLOR)
	var facing := Vector2.RIGHT.rotated(player.rotation)
	draw_line(center, center + facing * 16.0, PLAYER_COLOR, 2.0)
	draw_arc(center, 11.0, 0.0, TAU, 24, Color(PLAYER_COLOR.r, PLAYER_COLOR.g, PLAYER_COLOR.b, 0.45), 1.0, true)

	range_label.text = "%dm  ·  %d contact%s" % [
		int(GameConfig.SONAR_MAX_RANGE), contacts.size(), "" if contacts.size() == 1 else "s"
	]