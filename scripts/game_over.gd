extends CanvasLayer
## End-of-run screen. Offers a restart or a quit, per the brief.
##
## Restart reloads the current scene rather than trying to reset the world in
## place, so the player always gets a clean seed and fresh reefs and fish.

@onready var summary: Label = $Panel/Box/Summary
@onready var restart_button: Button = $Panel/Box/Restart
@onready var quit_button: Button = $Panel/Box/Quit


func _ready() -> void:
	visible = false
	restart_button.pressed.connect(_on_restart)
	quit_button.pressed.connect(_on_quit)


## Shown with the run's final tally. Restart also takes Enter, quit takes Esc,
## so the screen is playable without reaching for the mouse.
func show_summary(gold: int) -> void:
	summary.text = "Salvage recovered: %d gold" % gold
	visible = true


func hide_screen() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	# Both handlers tear the scene down, and this node lives inside the scene
	# being torn down. Consume the event first: get_viewport() returns null
	# afterwards, because there is no longer a viewport for this node to ask.
	# ui_accept is bound to Enter and Space by default.
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_restart()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_quit()


func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit() -> void:
	get_tree().paused = false
	get_tree().quit()
