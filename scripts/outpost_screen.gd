class_name OutpostScreen
extends CanvasLayer
## The outpost menu: the hull's numbers, a note, and the way back out.
##
## On its own always-processing layer like the harbour screen, so it keeps
## taking input while the tree is paused. There is deliberately nothing else to
## buy here: the supply post restocks nobody's stores but the tank.

signal dock_toggled

@onready var stats: Label = $Panel/Box/Stats
@onready var note: Label = $Panel/Box/Note
@onready var launch_button: Button = $Panel/Box/Launch

var _player: Player
var _missions: MissionDirector


func _ready() -> void:
	visible = false
	launch_button.pressed.connect(func() -> void: dock_toggled.emit())


func bind(player: Player) -> void:
	_player = player


## The note reads the errand's state, so it has to be told when that changes.
func bind_missions(missions: MissionDirector) -> void:
	_missions = missions
	if missions != null:
		missions.mission_changed.connect(_on_mission_changed)


func _on_mission_changed(_mission: int, _met: bool) -> void:
	if visible:
		refresh()


func refresh() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	stats.text = "SALVAGE  %d      HULL  %d / %d" % [
		_player.gold, _player.hp, _player.max_hp]
	if _missions != null:
		note.text = _missions.outpost_note()


## The dock key, reported exactly as the harbour screen reports it: claimed
## only while the hull is alongside or inside this anchorage, because the
## screen read first swallows the event for every screen read after it.
## The outpost node still decides whether the request means anything.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if not event.is_action("dock"):
		return
	var dock := get_parent() as Outpost
	if dock == null or not (dock.docked or dock.in_zone):
		return
	get_viewport().set_input_as_handled()
	dock_toggled.emit()
