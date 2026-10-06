class_name Spawner
extends Node2D
## Builds the world once, then quietly puts the fish back.
##
## Everything here is seeded, so a dive is the same dive every time. That is
## what makes a change to a speed or a count something you can actually judge:
## the water is held still while you change your mind about it. The seed lives
## in GameConfig rather than here, because it stopped being this node's business
## once reefs, coins and creatures started drawing from it as well.
##
## Terrain is laid down at start and never touched again. Living things are
## topped back up to their numbers, slowly and off-screen, because a world that
## refills the moment you clear it turns a good hunt into bookkeeping.

## Re-emitted for every enemy that dies, so whoever owns the consequences of a
## death can react without the spawner having to know what they are.
signal enemy_died(enemy: SeaEnemy)

## Terrain scales with the water rather than against it. The fish do not: a
## bigger map with the same number of them is the point, and thinning them out
## is what makes room to actually navigate instead of being surrounded on spawn.
const REEF_COUNT := 58
const WRECK_COUNT := 22

## How long between putting one of a species back, counted per species so a
## quiet stretch of fish does not hold up a crab.
##
## Slow on purpose. Emptying a shoal should stay worth something, so the world
## takes its time giving it back: kill all nine fish and the last one is still an
## hour and a half away. Refilling on a timer you can watch rather than
## snapping back the instant a firefight ends is the whole point.
const RESPAWN_INTERVAL := 12.0

## How far past the visible edge something appears. Comfortably more than the
## view so nothing is ever seen arriving.
const SPAWN_MARGIN := 160.0

## What the world holds, per species, and the cap it refills to, is no longer
## decided here. Spawn data lives beside the rest of a species' description in
## Species.PROFILES, so there is one list rather than two that have to agree.

@onready var player: Player = get_node_or_null("../Player") as Player
@onready var reef_container: Node2D = get_node_or_null("../Reefs") as Node2D
@onready var wreck_container: Node2D = get_node_or_null("../Wrecks") as Node2D
@onready var pickup_container: Node2D = get_node_or_null("../Pickups") as Node2D

var _rng: RandomNumberGenerator
## Seconds until each species is next topped up, keyed by id.
var _next_attempt := {}
## Scenes loaded once at start rather than on every respawn.
var _scenes := {}


func _ready() -> void:
	_rng = GameConfig.seeded_rng()
	_build_reefs()
	_build_wrecks()
	_load_species_scenes()
	_seed_population()


func _process(delta: float) -> void:
	# Nothing should swim back in while the run is over. The tree is paused by
	# then anyway, which stops this on its own; the check is here so the rule is
	# stated where the behaviour is.
	if player == null or not is_instance_valid(player) or player.hp <= 0:
		return

	for profile in Species.PROFILES:
		var id := profile.id
		var left := float(_next_attempt.get(id, RESPAWN_INTERVAL)) - delta
		if left > 0.0:
			_next_attempt[id] = left
			continue
		_next_attempt[id] = RESPAWN_INTERVAL
		_top_up(profile)


# --- Building the world ------------------------------------------------------

func _build_reefs() -> void:
	if reef_container == null:
		return
	for i in REEF_COUNT:
		var reef := Reef.new()
		reef.radius = _rng.randf_range(38.0, 96.0)
		reef.point_count = _rng.randi_range(7, 12)
		reef.jag = _rng.randf_range(0.25, 0.6)
		reef.position = _random_world_point()
		reef_container.add_child(reef)


## Wrecks are also loot sites. Coins are scattered around the hull of each
## wreck that holds any, so drifting into one is the main reason to slow down.
func _build_wrecks() -> void:
	if wreck_container == null:
		return
	for i in WRECK_COUNT:
		var wreck := Wreck.new()
		wreck.length = _rng.randf_range(80.0, 170.0)
		wreck.beam = _rng.randf_range(26.0, 44.0)
		wreck.tilt = _rng.randf_range(-0.35, 0.35)
		wreck.position = _random_world_point()
		wreck.rotation = _rng.randf_range(0.0, TAU)
		wreck_container.add_child(wreck)
		_scatter_wreck_loot(wreck)


func _scatter_wreck_loot(wreck: Wreck) -> void:
	if pickup_container == null:
		return
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


# --- Stock -------------------------------------------------------------------

func _load_species_scenes() -> void:
	for profile in Species.PROFILES:
		var scene := load(profile.scene_path) as PackedScene
		if scene == null:
			push_error("Spawner: could not load %s" % profile.scene_path)
			continue
		_scenes[profile.id] = scene


## Fills the water to its numbers, and staggers the first refill so two species
## are never both due on the same frame.
func _seed_population() -> void:
	var total := Species.PROFILES.size()
	for i in total:
		var profile := Species.PROFILES[i]
		for n in profile.population:
			_spawn_one(profile)
		_next_attempt[profile.id] = RESPAWN_INTERVAL * float(i + 1) / float(total)


## Adds one of a species to its container. The container is named by the species
## and sits beside this node rather than inside it, so it is reached from up a
## level.
func _container_for(profile: Species.Profile) -> Node2D:
	return get_node_or_null("../%s" % profile.container) as Node2D


## One more of a species, if the water has room for it.
func _top_up(profile: Species.Profile) -> void:
	var container := _container_for(profile)
	if container == null:
		push_error("Spawner: no container node named %s" % profile.container)
		return
	# Children are freed on death, so the count is the truth. It lags a frame
	# behind a kill because freeing is deferred, which against a twelve second
	# clock is not worth measuring.
	if container.get_child_count() >= profile.population:
		return
	_spawn_one(profile)


func _spawn_one(profile: Species.Profile) -> void:
	var scene := _scenes.get(profile.id) as PackedScene
	var container := _container_for(profile)
	if scene == null or container == null:
		return
	var enemy := scene.instantiate() as SeaEnemy
	if enemy == null:
		push_error("Spawner: %s did not instantiate as a SeaEnemy" % profile.scene_path)
		return
	enemy.position = _offscreen_point()
	# Identity comes from here rather than from the creature declaring its own.
	# We already hold the profile we spawned it from, so there is no reason to
	# let the two be told separately and disagree. Set before it enters the tree
	# so it is never briefly nameless.
	enemy.apply_profile(profile)
	enemy.died.connect(_on_enemy_died)
	container.add_child(enemy)


func _on_enemy_died(dead: SeaEnemy) -> void:
	enemy_died.emit(dead)


# --- Placement ---------------------------------------------------------------

func _random_world_point() -> Vector2:
	var h := GameConfig.WORLD_HALF - 100.0
	return Vector2(_rng.randf_range(-h, h), _rng.randf_range(-h, h))


## A point beyond the visible viewport edge, projected from the player's
## position so creatures always enter from off-screen.
func _offscreen_point() -> Vector2:
	if player == null or not is_instance_valid(player):
		return _random_world_point()
	var margin := _visible_half_diagonal() + SPAWN_MARGIN
	for attempt in 24:
		var angle := _rng.randf_range(0.0, TAU)
		var candidate := player.position + Vector2.RIGHT.rotated(angle) * margin
		if absf(candidate.x) <= GameConfig.WORLD_HALF \
				and absf(candidate.y) <= GameConfig.WORLD_HALF:
			return candidate
		margin += 80.0
	return _random_world_point()


## Half-diagonal of the visible world area, in world units. The viewport rect
## is in pixels, so camera zoom has to come back out or spawns land ~1/zoom too
## far from the hull and drift in late.
func _visible_half_diagonal() -> float:
	var viewport := get_viewport_rect().size
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	var zoom := cam.zoom if cam != null else Vector2.ONE
	return Vector2(viewport.x / zoom.x, viewport.y / zoom.y).length() * 0.5