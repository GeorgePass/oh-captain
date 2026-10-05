extends Node2D
## World root: generates reefs, wrecks, and fish; wires the camera and HUD.

const WORLD_SEED := 20260905

const REEF_COUNT := 42
const WRECK_COUNT := 16
const FISH_COUNT := 14

## Fish spawn on a ring outside the viewport so they never appear on top of
## the player at start.
const FISH_SPAWN_MARGIN := 160.0

@onready var player: Player = $World/Player
@onready var reefs: Node2D = $World/Reefs
@onready var wrecks: Node2D = $World/Wrecks
@onready var fish_container: Node2D = $World/Fish
@onready var camera: Camera2D = $World/Camera2D
@onready var hud: CanvasLayer = $HUD

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = WORLD_SEED
	_spawn_reefs()
	_spawn_wrecks()
	_spawn_fish()
	player.died.connect(_on_player_died)
	hud.bind(player)
	camera.make_current()


func _spawn_reefs() -> void:
	for i in REEF_COUNT:
		var reef := Reef.new()
		reef.radius = _rng.randf_range(38.0, 96.0)
		reef.point_count = _rng.randi_range(7, 12)
		reef.jag = _rng.randf_range(0.25, 0.6)
		reef.position = _random_world_point()
		reefs.add_child(reef)


func _spawn_wrecks() -> void:
	for i in WRECK_COUNT:
		var wreck := Wreck.new()
		wreck.length = _rng.randf_range(80.0, 170.0)
		wreck.beam = _rng.randf_range(26.0, 44.0)
		wreck.tilt = _rng.randf_range(-0.35, 0.35)
		wreck.position = _random_world_point()
		wreck.rotation = _rng.randf_range(0.0, TAU)
		wrecks.add_child(wreck)


func _spawn_fish() -> void:
	var scene := load("res://scenes/fish.tscn") as PackedScene
	if scene == null:
		push_error("Main: could not load res://scenes/fish.tscn")
		return
	for i in FISH_COUNT:
		var fish := scene.instantiate() as EnemyFish
		fish.position = _offscreen_point()
		fish_container.add_child(fish)


func _random_world_point() -> Vector2:
	var h := GameConfig.WORLD_HALF - 100.0
	return Vector2(_rng.randf_range(-h, h), _rng.randf_range(-h, h))


## A point beyond the visible viewport edge, projected from the player's
## position so fish always enter from off-screen.
func _offscreen_point() -> Vector2:
	var margin := _viewport_half_diagonal() + FISH_SPAWN_MARGIN
	for attempt in 24:
		var angle := _rng.randf_range(0.0, TAU)
		var candidate := player.position + Vector2.RIGHT.rotated(angle) * margin
		if absf(candidate.x) <= GameConfig.WORLD_HALF \
				and absf(candidate.y) <= GameConfig.WORLD_HALF:
			return candidate
		margin += 80.0
	return _random_world_point()


func _viewport_half_diagonal() -> float:
	var viewport := get_viewport_rect().size
	return Vector2(viewport.x, viewport.y).length() * 0.5


func _on_player_died(_player: Node2D) -> void:
	# v1 has no game-over flow; just stop the hull acting on input.
	player.set_physics_process(false)