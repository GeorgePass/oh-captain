class_name Outpost
extends Node2D
## The supply post on the far side of the water.
##
## The mirror of the harbour, deliberately thin: it docks the same way, holds
## the tree still the same way and refills the tank the same way, but it sells
## nothing and takes no contracts. Its one piece of business is the delivery
## errand - Main asks the MissionDirector about that when the hull comes
## alongside, and this node never has to know the rules.

signal docked_changed(docked: bool)

@onready var screen: OutpostScreen = $OutpostScreen
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


## The screen reports the keypress; this decides what it was worth, exactly as
## the harbour does. Each screen claims the dock key only for its own
## anchorage - whichever screen the input order reads first swallows the event
## for everyone after it, so the guard has to live at the screen, not here.
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


## A smaller, plainer sibling of the harbour: a squared platform with a slip,
## and a cyan beacon so the far-side anchorage is findable from across the map.
func _draw() -> void:
	var size := GameConfig.OUTPOST_SIZE
	var half := size * 0.5
	var body := Rect2(-half, size)

	draw_rect(body, Color(0.13, 0.18, 0.22))
	draw_rect(Rect2(-half.x, -half.y, size.x, 10.0), Color(0.22, 0.46, 0.52))
	draw_rect(body, Color(0.30, 0.55, 0.60), false, 3.0)

	# The slip, like the harbour's but narrower.
	draw_rect(Rect2(-46.0, half.y - 40.0, 92.0, 40.0), Color(0.06, 0.09, 0.12))
	draw_arc(Vector2(0.0, half.y - 20.0), 45.0, 0.0, TAU, 32,
		Color(0.45, 0.9, 0.85, 0.7), 2.5, true)

	# Bollards along the frontage.
	for i in 5:
		var x := -half.x + 28.0 + float(i) * (size.x - 56.0) / 4.0
		draw_circle(Vector2(x, half.y - 8.0), 4.0, Color(0.62, 0.55, 0.30))

	# Beacon, cyan so it reads as the outpost and not the harbour.
	draw_circle(Vector2(half.x - 22.0, -half.y + 22.0), 7.0, Color(0.55, 0.95, 0.9))
	draw_arc(Vector2(half.x - 22.0, -half.y + 22.0), 13.0, 0.0, TAU, 24,
		Color(0.55, 0.95, 0.9, 0.45), 2.0, true)

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-half.x + 24.0, -half.y + 34.0), "OUTPOST",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, Color(0.75, 0.92, 0.95))