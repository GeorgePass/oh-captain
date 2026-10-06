extends Control
## Circular radar: player at centre with a facing tick, the harbour pinned to
## the rim whenever it is off-range, revealed fish as red dots, and a ring +
## bracket on the locked target.

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
## The harbour's beacon and frontage, matching the colours the world paints.
const HARBOR_BEACON := Color(1.0, 0.85, 0.45)
const HARBOR_WALL := Color(0.42, 0.47, 0.54)
## The outpost's cyan beacon and its platform, matching outpost.gd.
const OUTPOST_BEACON := Color(0.55, 0.95, 0.9)
const OUTPOST_WALL := Color(0.22, 0.46, 0.52)
## The recover errand's crate, the colour Item paints it in the water.
const CRATE_COLOR := Color(0.72, 0.60, 0.40)
## How far off-range markers keep from the rim so they stay on the disc.
const CONTACT_MARGIN := 5.0
const HARBOR_MARGIN := 13.0

@onready var range_label: Label = $RangeLabel

var player: Player
## The harbourmaster's errands. Null until Main wires it, so the radar keeps
## working in any scene that has a player but no missions.
var missions: MissionDirector


func _ready() -> void:
	resized.connect(queue_redraw)


func _radius() -> float:
	return minf(size.x, size.y) * 0.5 - 6.0


## Clamps an off-disc position to the rim along its bearing instead of culling
## it, so anything that drifts past the edge keeps pointing the right way. The
## margin keeps the marker inside the ring rather than straddling it.
func _pin_to_rim(center: Vector2, radius: float, rel: Vector2, margin: float) -> Vector2:
	var rim := radius - margin
	return center + rel.normalized() * rim if rel.length() > rim else center + rel


## The harbour in miniature: the same quay wall and gold beacon the world
## builds, small enough that the beacon still reads on the radar.
func _draw_harbor(at: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(-7.0, -4.0), Vector2(14.0, 9.0)), HARBOR_WALL)
	draw_rect(Rect2(at + Vector2(-7.0, -4.0), Vector2(5.0, 9.0)), Color(0.62, 0.55, 0.30))
	var beacon := at + Vector2(6.0, -7.0)
	draw_circle(beacon, 3.2, HARBOR_BEACON)
	draw_arc(beacon, 5.8, 0.0, TAU, 16, Color(HARBOR_BEACON.r, HARBOR_BEACON.g, HARBOR_BEACON.b, 0.45), 1.4, true)


## The outpost in miniature: a cyan beacon on a smaller platform, so the far
## anchorage is told apart from the harbour at a glance.
func _draw_outpost(at: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(-6.0, -3.0), Vector2(12.0, 8.0)), OUTPOST_WALL)
	var beacon := at + Vector2(5.0, -6.0)
	draw_circle(beacon, 3.0, OUTPOST_BEACON)
	draw_arc(beacon, 5.6, 0.0, TAU, 16, Color(OUTPOST_BEACON.r, OUTPOST_BEACON.g, OUTPOST_BEACON.b, 0.42), 1.4, true)


## The recover errand's wreck: the same crate the world paints on its deck, so
## the radar pin and the thing you swim to are recognisably the same.
func _draw_mission_site(at: Vector2) -> void:
	var r := 6.0
	draw_rect(Rect2(at + Vector2(-r, -r), Vector2(r * 2.0, r * 2.0)), CRATE_COLOR)
	draw_rect(Rect2(at + Vector2(-r + 1.5, -r + 1.5), Vector2(r * 2.0 - 3.0, r * 2.0 - 3.0)),
		Color(0.35, 0.26, 0.14), false, 1.4)


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
		var rel := GameConfig.wrapped_delta(player.global_position, contact.global_position) * scale
		# Clamp instead of cull: a contact beyond range still hugs the rim.
		var dot := _pin_to_rim(center, radius, rel, CONTACT_MARGIN)
		# Same three colours the creatures themselves are drawn in, so the
		# radar state and the world state agree.
		var tint := CONTACT_COLOR
		if contact.is_fleeing():
			tint = FLEEING_COLOR
		elif contact.is_hostile():
			tint = HOSTILE_COLOR
		elif contact.is_alert():
			tint = ALERT_COLOR
		# Heavier creatures get a halo so they read as heavier at a glance.
		# Asked of the creature rather than tested for by class, so a new
		# species is described by its entry in Species and nothing else.
		var voice := contact.profile()
		if voice != null and voice.radar_halo > 0.0:
			draw_arc(dot, voice.radar_halo, 0.0, TAU, 14, tint.darkened(0.2), 1.6, true)
		draw_circle(dot, 4.5, tint)

		if contact == locked:
			draw_line(center, dot, BEAM_COLOR, 1.0)
			draw_arc(dot, 10.0, 0.0, TAU, 24, LOCK_COLOR, 2.0, true)
			# Corner ticks read as a reticle even at small sizes.
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				draw_line(dot + corner * 10.0, dot + corner * 14.0, LOCK_COLOR, 1.5)

	# The harbour is the one thing the radar does not cull. Inside sonar range
	# it sits at its true bearing; past that the same marker is pinned to the
	# rim, so the way home stays readable even from the far corner of the map.
	var harbor_rel := GameConfig.wrapped_delta(player.global_position, GameConfig.HARBOR_POSITION) * scale
	_draw_harbor(_pin_to_rim(center, radius, harbor_rel, HARBOR_MARGIN))

	# The outpost is a fixture too, and the delivery errand's whole destination,
	# so it earns the same always-on marker in cyan.
	var outpost_rel := GameConfig.wrapped_delta(player.global_position, GameConfig.OUTPOST_POSITION) * scale
	_draw_outpost(_pin_to_rim(center, radius, outpost_rel, HARBOR_MARGIN))

	# The recover errand's wreck shows only while that errand is under way, and
	# only until the crate is aboard: once you have it, the site's job is done.
	if missions != null \
			and missions.active == MissionDirector.ID.RECOVER \
			and not missions.objective_met:
		var wreck_rel := GameConfig.wrapped_delta(player.global_position, GameConfig.MISSION_WRECK_POSITION) * scale
		_draw_mission_site(_pin_to_rim(center, radius, wreck_rel, HARBOR_MARGIN))

	# Player mark: hull dot plus a heading tick.
	draw_circle(center, 5.5, PLAYER_COLOR)
	var facing := Vector2.RIGHT.rotated(player.rotation)
	draw_line(center, center + facing * 16.0, PLAYER_COLOR, 2.0)
	draw_arc(center, 11.0, 0.0, TAU, 24, Color(PLAYER_COLOR.r, PLAYER_COLOR.g, PLAYER_COLOR.b, 0.45), 1.0, true)

	range_label.text = "%dm  ·  %d contact%s" % [
		roundi(GameConfig.SONAR_MAX_RANGE), contacts.size(), "" if contacts.size() == 1 else "s"
	]