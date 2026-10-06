class_name HarborScreen
extends CanvasLayer
## The harbour menu, and the way back out.
##
## It sits on its own layer above the HUD with process_mode ALWAYS, so it keeps
## taking input while the tree is paused — which is the entire point of docking,
## and the reason the dock key is handled here rather than on the harbour node.
## The menu underneath is deliberately inert for now: shop and missions arrive
## with later steps of the build, and the launch button is the whole loop until
## then.

signal dock_toggled

@onready var stats: Label = $Panel/Box/Stats
@onready var launch_button: Button = $Panel/Box/Launch

var _player: Player


func _ready() -> void:
	visible = false
	launch_button.pressed.connect(func() -> void: dock_toggled.emit())


## The hull's numbers are read on demand rather than pushed, because nothing
## can change while the tree is paused anyway: the only moment this needs to be
## right is the moment the menu opens.
func bind(player: Player) -> void:
	_player = player


func refresh() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	stats.text = "SALVAGE  %d      HULL  %d / %d      TORPEDOES  %d / %d" % [
		_player.gold, _player.hp, _player.max_hp, _player.ammo, _player.max_ammo]


## The dock key. Guarded on nothing: pressing it out at sea is a no-op, because
## the harbour node decides whether the request means anything, and this screen
## only ever reports that the key went down.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action("dock"):
		get_viewport().set_input_as_handled()
		dock_toggled.emit()
