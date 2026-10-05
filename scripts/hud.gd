extends CanvasLayer
## HUD: vitals top-left, radar centred, and the three action buttons.

@onready var hp_label: Label = $Vitals/HP
@onready var hp_bar: ProgressBar = $Vitals/HPBar
@onready var ammo_label: Label = $Vitals/Ammo
@onready var gold_label: Label = $Vitals/Gold
@onready var sonar_display: Control = $SonarDisplay
@onready var sonar_button: Button = $Controls/SonarButton
@onready var lock_button: Button = $Controls/LockButton
@onready var fire_button: Button = $Controls/FireButton

var player: Player


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
	_on_hp_changed(player.hp, player.max_hp)
	_on_ammo_changed(player.ammo, player.max_ammo)
	_on_gold_changed(player.gold)
	_refresh_buttons()


func _process(_delta: float) -> void:
	_refresh_buttons()


func _refresh_buttons() -> void:
	if player == null or not is_instance_valid(player):
		return
	var sonar := player.sonar()

	if sonar != null and sonar.cooldown > 0.0:
		sonar_button.text = "Sonar  %.1fs" % sonar.cooldown
		sonar_button.disabled = true
	else:
		var mode := "ACTIVE" if sonar != null and sonar.mode == Sonar.Mode.ACTIVE else "PASSIVE"
		sonar_button.text = "Sonar: %s  [Tab]" % mode
		sonar_button.disabled = false

	var count := player.contacts().size()
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


func _on_fire_state_changed() -> void:
	_refresh_buttons()


func _on_lock_changed(target: Node2D) -> void:
	if target != null:
		lock_button.text = "Locked: %s  [Q]" % target.name
	_refresh_buttons()