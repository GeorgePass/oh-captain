class_name Harbor
extends Node2D
## The one fixed place in a world that wraps.
##
## Everything else here drifts, respawns or wraps; this does not. It sits at the
## single point `wrap_position` leaves alone, and it is solid on the reef layer,
## so the water already knows how to treat it — the hull cannot swim in, torpedoes
## detonate against it, and it occludes sound and sonar exactly as rock does,
## without any of that having to be stated twice.
##
## Docking is a decision made from a screen that keeps running while the tree is
## paused, which is what docking does. So the key lives there, and this node is
## what decides whether pressing it means anything.

signal docked_changed(docked: bool)

@onready var screen: HarborScreen = $HarborScreen
@onready var hint: Label = $DockHintLayer/Hint
@onready var zone: Area2D = $DockZone

## Whether the hull is inside the anchorage, and therefore allowed to dock.
var in_zone := false
## Whether the run is currently held still.
var docked := false

var _player: Player


func _ready() -> void:
	_player = get_node_or_null("../Player") as Player
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)
	screen.dock_toggled.connect(_on_dock_toggled)
	screen.bind(_player)
	screen.visible = false
	hint.visible = false


## The screen reports the keypress; this decides what it was worth. Open only
## from inside the anchorage, and never over the death screen — otherwise a
## stray H at the moment of dying would raise a menu above the only screen that
## can end the run.
func _on_dock_toggled() -> void:
	if docked:
		set_docked(false)
	elif in_zone and _player != null and is_instance_valid(_player) and _player.hp > 0:
		set_docked(true)


func set_docked(value: bool) -> void:
	if docked == value:
		return
	docked = value
	screen.visible = docked
	if docked:
		screen.refresh()
	hint.visible = in_zone and not docked
	docked_changed.emit(docked)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		in_zone = true
		hint.visible = not docked


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		in_zone = false
		hint.visible = false


## Built concrete, drawn rather than generated: straight edges, a lit slip to
## aim at, and a beacon so the anchorage is findable from the far side of the
## map. The structure is centred on HARBOR_POSITION, and the collision is a
## plain rectangle under it, so what you see is what stops you.
func _draw() -> void:
	var size := GameConfig.HARBOR_SIZE
	var half := size * 0.5
	var body := Rect2(-half, size)

	# Quayside, then the water-facing lip it casts a shadow onto.
	draw_rect(body, Color(0.15, 0.17, 0.21))
	draw_rect(Rect2(-half.x, -half.y, size.x, 10.0), Color(0.34, 0.38, 0.44))
	draw_rect(body, Color(0.42, 0.47, 0.54), false, 3.0)

	# The slip: the notch you point the bow at when coming alongside.
	draw_rect(Rect2(-64.0, half.y - 54.0, 128.0, 54.0), Color(0.08, 0.10, 0.13))
	draw_arc(Vector2(0.0, half.y - 27.0), 62.0, 0.0, TAU, 32,
		Color(0.45, 0.9, 0.85, 0.7), 2.5, true)

	# Bollards along the frontage.
	for i in 7:
		var x := -half.x + 36.0 + float(i) * (size.x - 72.0) / 6.0
		draw_circle(Vector2(x, half.y - 8.0), 4.5, Color(0.62, 0.55, 0.30))

	# Beacon. Still, so it reads as structure rather than as something alive.
	draw_circle(Vector2(half.x - 22.0, -half.y + 22.0), 7.0, Color(1.0, 0.85, 0.45))
	draw_arc(Vector2(half.x - 22.0, -half.y + 22.0), 13.0, 0.0, TAU, 24,
		Color(1.0, 0.85, 0.45, 0.45), 2.0, true)

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-half.x + 24.0, -half.y + 34.0), "HARBOR",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, Color(0.82, 0.86, 0.92))
