extends Node2D
## Root of a run: owns the consequences of things happening, not the things
## themselves.
##
## Building the world and putting fish back is the Spawner's job. What is left
## here is the part that is neither generation nor simulation: how a death
## ripples out to everything still alive, how a dive is held still while the
## captain is alongside, and how a run ends.

@onready var player: Player = $World/Player
@onready var spawner: Spawner = $World/Spawner
@onready var harbor: Harbor = $World/Harbor
@onready var oxygen: Oxygen = $Oxygen
@onready var hud: Hud = $HUD
@onready var game_over: CanvasLayer = $GameOver


func _ready() -> void:
	spawner.enemy_died.connect(_on_enemy_died)
	player.died.connect(_on_player_died)
	hud.bind(player)
	hud.bind_oxygen(oxygen)
	# Connected before the first dock rather than after it. The run opens
	# alongside — the hull starts next to the harbour, with a full tank and
	# nowhere to be yet — and a child that emits during its parent's setup is
	# easy to have missed. This is the one call in the run that happens before
	# the tree has processed a frame, so it has to be wired first or nobody
	# would ever pause.
	harbor.docked_changed.connect(_on_docked_changed)
	# The counter reads the cargo panel's selection, so the two have to meet
	# before the first dock, which opens the panel right alongside the menu.
	harbor.screen.bind_shop(hud.inventory)
	game_over.hide_screen()
	harbor.set_docked(true)


## Docking is a pause and nothing else: no special case for enemies, no
## immunity flag, no timer. Holding the tree still is what makes the harbour
## safe, and it is also what freezes the tank, the fish and the pings — one
## rule doing three jobs.
##
## The cargo panel rides along because it is the counter's window: alongside,
## it is open for the sale the menu is offering, and the moment the captain
## undocks it closes and stops indicating anything — a highlight that outlives
## the window it was drawn in is how a sale sells the wrong stack.
func _on_docked_changed(docked: bool) -> void:
	get_tree().paused = docked
	if docked:
		oxygen.refill()
	hud.inventory.set_open(docked)


## Relays a death to everything still alive. A fish bolts when it sees a
## sibling go, however healthy it was; anything tougher carries on hunting.
## Broadcasting from here rather than from each enemy keeps the wiring in one
## place and means a fish spawned later is covered automatically.
##
## The sonar is told too. A contact is a claim that something alive is out
## there, and without this the radar carried a dead fish around on its dot for
## the full sixteen seconds before the contact timed out on its own.
func _on_enemy_died(dead: SeaEnemy) -> void:
	var at := dead.global_position
	# Guarded because a shot already in flight can land on the frame a restart
	# tears the old world down, and calling into a freed hull is its own crash.
	if is_instance_valid(player):
		var sonar := player.sonar()
		if sonar != null:
			sonar.drop(dead)
	for node in get_tree().get_nodes_in_group(SeaEnemy.GROUP):
		var enemy := node as SeaEnemy
		if enemy == null or enemy == dead:
			continue
		enemy.on_neighbour_died(at)


## Runs are terminal: the hull stops acting on input, the tree pauses so
## nothing keeps hunting in the background, and the end screen offers a fresh
## dive or a quit.
func _on_player_died(_player: Node2D) -> void:
	player.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group(SeaEnemy.GROUP):
		if is_instance_valid(enemy):
			(enemy as SeaEnemy).set_passive()
	game_over.show_summary(player.gold)
	AudioDirector.play(get_tree(), &"game_over")
	get_tree().paused = true