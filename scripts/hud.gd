class_name Hud
extends CanvasLayer
## HUD: vitals top-left, radar centred, and the three action buttons.

@onready var hp_label: Label = $Vitals/HP
@onready var hp_bar: ProgressBar = $Vitals/HPBar
@onready var oxygen_label: Label = $Vitals/Oxygen
@onready var oxygen_bar: ProgressBar = $Vitals/OxygenBar
@onready var ammo_label: Label = $Vitals/Ammo
@onready var gold_label: Label = $Vitals/Gold
@onready var sonar_display: Control = $SonarDisplay
@onready var sonar_button: Button = $Controls/SonarButton
@onready var lock_button: Button = $Controls/LockButton
@onready var fire_button: Button = $Controls/FireButton
@onready var drowning_rect: ColorRect = $Drowning

var player: Player

## Where the radar sits when the water is calm, so drowning can shake it off
## that mark and put it back rather than accumulate a drift.
var _sonar_home := Vector2.ZERO
var _drowning := false


func bind(target: Player) -> void:
	player = target
	player.hp_changed.connect(_on_hp_changed)
	player.ammo_changed.connect(_on_ammo_changed)
	player.gold_changed.connect(_on_gold_changed)
	player.fire_state_changed.connect(_on_fire_state_changed)
	player.lock_changed.connect(_on_lock_changed)

	sonar_button.pressed.connect(func() -> void: player.toggle_sonar())
	lock_button.pressed.connect(func() -> void: player.cycle_lock())
	fire_button.pressed.connect(func() -> void: player.fire())

	sonar_display.player = player
	_sonar_home = sonar_display.position
	_on_hp_changed(player.hp, player.max_hp)
	_on_ammo_changed(player.ammo, player.max_ammo)
	_on_gold_changed(player.gold)
	_refresh_buttons()


## The tank is wired separately from the hull because it is a separate clock:
## it belongs to the run rather than to the boat, and it can empty while every
## other reading here stays perfectly still.
func bind_oxygen(oxygen: Oxygen) -> void:
	oxygen.oxygen_changed.connect(_on_oxygen_changed)
	oxygen.drowning_changed.connect(_on_drowning_changed)
	_on_oxygen_changed(oxygen.current, GameConfig.OXYGEN_MAX)


func _process(_delta: float) -> void:
	_refresh_buttons()
	# Readings jitter while drowning, as §4.4 asks: an alarm that makes the
	# instruments themselves harder to read is doing its job. Visual only —
	# nothing here changes a number the simulation acts on.
	if _drowning:
		sonar_display.position = _sonar_home + Vector2(
			randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))


func _refresh_buttons() -> void:
	if player == null or not is_instance_valid(player):
		return
	var sonar := player.sonar()

	# While continuous pinging is on the button stays live even during the
	# cooldown, because it is how you turn it back off.
	if sonar != null and sonar.continuous:
		if sonar.cooldown > 0.0:
			sonar_button.text = "Sonar: ON  next %.1fs" % sonar.cooldown
		else:
			sonar_button.text = "Sonar: ON  [Tab]"
		sonar_button.disabled = false
	elif sonar != null and sonar.cooldown > 0.0:
		sonar_button.text = "Sonar  %.1fs" % sonar.cooldown
		sonar_button.disabled = true
	else:
		var mode := "ACTIVE" if sonar != null and sonar.mode == Sonar.Mode.ACTIVE else "PASSIVE"
		sonar_button.text = "Sonar: %s  [Tab]" % mode
		sonar_button.disabled = false

	# Lock counts what is in sight, not what the sonar has found.
	var count := player.lockable().size()
	lock_button.text = "Lock: %d  [Q]" % count
	lock_button.disabled = count == 0 or player.locked_target == null

	fire_button.text = "Fire (%d)  [E]" % player.ammo
	fire_button.disabled = not player.can_fire()


func _on_hp_changed(hp: int, max_hp: int) -> void:
	hp_label.text = "HULL  %d / %d" % [hp, max_hp]
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_bar.modulate = Color(1.0, 0.35, 0.3) if hp <= max_hp / 3 else Color(0.4, 0.9, 0.7)


func _on_ammo_changed(ammo: int, max_ammo: int) -> void:
	ammo_label.text = "TORPEDOES  %d / %d" % [ammo, max_ammo]


func _on_gold_changed(gold: int) -> void:
	gold_label.text = "SALVAGE  %d" % gold


func _on_oxygen_changed(current: float, max_oxygen: float) -> void:
	oxygen_label.text = "OXYGEN  %d%%" % int(current / max_oxygen * 100.0)
	oxygen_bar.max_value = max_oxygen
	oxygen_bar.value = current
	# Turns against you well before it reaches zero, so the alarm has a run-up
	# rather than arriving on the same frame the damage does.
	oxygen_bar.modulate = Color(1.0, 0.45, 0.35) if current <= max_oxygen * 0.25 \
		else Color(0.5, 0.8, 1.0)


func _on_drowning_changed(drowning: bool) -> void:
	_drowning = drowning
	drowning_rect.visible = drowning
	# The sonar dims as well as jitters: past empty the picture you are reading
	# is the first thing to go, which is what makes the last few seconds of air
	# feel different from the first.
	sonar_display.modulate = Color(0.62, 0.66, 0.7) if drowning else Color.WHITE
	if not drowning:
		sonar_display.position = _sonar_home


func _on_fire_state_changed() -> void:
	_refresh_buttons()


func _on_lock_changed(_target: Node2D) -> void:
	# The lock's identity is carried by the bracket on the target and the
	# reticle on the radar, so the button just re-reads the count. Naming the
	# target here would be overwritten by `_refresh_buttons` on the same call.
	_refresh_buttons()