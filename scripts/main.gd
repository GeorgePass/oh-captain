extends Node2D
## World root: generates reefs, wrecks, and fish; wires the camera and HUD.

const WORLD_SEED := 20260905

const REEF_COUNT := 42
const WRECK_COUNT := 16
const FISH_COUNT := 14
const CRAB_COUNT := 4

## Fish spawn on a ring outside the viewport so they never appear on top of
## the player at start.
const FISH_SPAWN_MARGIN := 160.0

@onready var player: Player = $World/Player
@onready var reefs: Node2D = $World/Reefs
@onready var wrecks: Node2D = $World/Wrecks
@onready var fish_container: Node2D = $World/Fish
@onready var crab_container: Node2D = $World/Crabs
@onready var pickup_container: Node2D = $World/Pickups
@onready var hud: CanvasLayer = $HUD
@onready var game_over: CanvasLayer = $GameOver

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = WORLD_SEED
	_spawn_reefs()
	_spawn_wrecks()
	_spawn_fish()
	_spawn_crabs()
	player.died.connect(_on_player_died)
	hud.bind(player)
	game_over.hide_screen()


func _spawn_reefs() -> void:
	for i in REEF_COUNT:
		var reef := Reef.new()
		reef.radius = _rng.randf_range(38.0, 96.0)
		reef.point_count = _rng.randi_range(7, 12)
		reef.jag = _rng.randf_range(0.25, 0.6)
		reef.position = _random_world_point()
		reefs.add_child(reef)


## Wrecks are also loot sites. Coins are scattered around the hull of each
## wreck that holds any, so drifting into one is the main reason to slow down.
func _spawn_wrecks() -> void:
	for i in WRECK_COUNT:
		var wreck := Wreck.new()
		wreck.length = _rng.randf_range(80.0, 170.0)
		wreck.beam = _rng.randf_range(26.0, 44.0)
		wreck.tilt = _rng.randf_range(-0.35, 0.35)
		wreck.position = _random_world_point()
		wreck.rotation = _rng.randf_range(0.0, TAU)
		wrecks.add_child(wreck)
		_scatter_wreck_loot(wreck)


func _scatter_wreck_loot(wreck: Wreck) -> void:
	if _rng.randf() > GameConfig.WRECK_GOLD_CHANCE:
		return
	var total := _rng.randi_range(GameConfig.WRECK_GOLD_MIN, GameConfig.WRECK_GOLD_MAX)
	var coins := _rng.randi_range(GameConfig.WRECK_COINS_MIN, GameConfig.WRECK_COINS_MAX)
	coins = mini(coins, total)
	var per_coin := maxi(1, total / coins)
	var spread := wreck.length * 0.7
	for i in coins:
		var coin := Pickup.spawn(pickup_container, wreck.position + Vector2(
			_rng.randf_range(-spread, spread),
			_rng.randf_range(-spread * 0.6, spread * 0.6)))
		if coin == null:
			continue
		coin.amount = per_coin
		# Nudged along the wreck's own axis so the coins read as spilled from
		# it rather than sprinkled in a circle.
		coin.nudge(Vector2.from_angle(wreck.rotation) * _rng.randf_range(-30.0, 30.0))


func _spawn_fish() -> void:
	var scene := load("res://scenes/fish.tscn") as PackedScene
	if scene == null:
		push_error("Main: could not load res://scenes/fish.tscn")
		return
	for i in FISH_COUNT:
		var fish := scene.instantiate() as EnemyFish
		fish.position = _offscreen_point()
		fish_container.add_child(fish)


## Crabs spawn off-screen too, but with a wider margin so a slow one cannot
## trundle into view on its own during the opening seconds.
func _spawn_crabs() -> void:
	var scene := load("res://scenes/crab.tscn") as PackedScene
	if scene == null:
		push_error("Main: could not load res://scenes/crab.tscn")
		return
	for i in CRAB_COUNT:
		var crab := scene.instantiate() as EnemyCrab
		crab.position = _offscreen_point()
		crab_container.add_child(crab)


func _random_world_point() -> Vector2:
	var h := GameConfig.WORLD_HALF - 100.0
	return Vector2(_rng.randf_range(-h, h), _rng.randf_range(-h, h))


## A point beyond the visible viewport edge, projected from the player's
## position so fish always enter from off-screen.
func _offscreen_point() -> Vector2:
	var margin := _visible_half_diagonal() + FISH_SPAWN_MARGIN
	for attempt in 24:
		var angle := _rng.randf_range(0.0, TAU)
		var candidate := player.position + Vector2.RIGHT.rotated(angle) * margin
		if absf(candidate.x) <= GameConfig.WORLD_HALF \
				and absf(candidate.y) <= GameConfig.WORLD_HALF:
			return candidate
		margin += 80.0
	return _random_world_point()


## Half-diagonal of the visible world area, in world units. The viewport rect
## is in pixels, so camera zoom has to come back out or fish spawn ~1/zoom
## too far from the hull and drift in late.
func _visible_half_diagonal() -> float:
	var viewport := get_viewport_rect().size
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	var zoom := cam.zoom if cam != null else Vector2.ONE
	return Vector2(viewport.x / zoom.x, viewport.y / zoom.y).length() * 0.5


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