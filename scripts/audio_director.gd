class_name AudioDirector
extends Node
## Owns every sound in the game.
##
## Nothing in the project ships an audio file: AudioDirector builds the whole
## set once in _ready() from Sfx and caches it, then hands out pooled players.
## One-shots go through AudioStreamPlayer, world sounds through
## AudioStreamPlayer2D so panning and distance falloff are free.
##
## Call sites use the static helpers, which look the director up and no-op if
## it is missing, so no gameplay code needs a null check:
##     AudioDirector.play(get_tree(), &"ping")
##     AudioDirector.play_at(get_tree(), &"cry_hostile_fish", global_position)

const GROUP := "audio"

## Mirrors SeaEnemy.State. Duplicated as plain ints so the sound keys can be
## built without Sfx or the enemy AI depending on each other.
const PASSIVE := 0
const ALERT := 1
const HOSTILE := 2
const FLEEING := 3

const SFX_POOL := 12
const POSITIONAL_POOL := 20

var muted := false

var _streams: Dictionary = {}
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _pos_pool: Array[AudioStreamPlayer2D] = []
var _pos_next := 0
var _ambient: AudioStreamPlayer


func _ready() -> void:
	# Runs while the tree is paused, so M still works on the end screen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	_build_streams()
	_build_pools()
	_start_ambient()


# --- Static entry points -----------------------------------------------------

static func play(tree: SceneTree, key: StringName, volume_db := 0.0) -> void:
	var d := _find(tree)
	if d != null:
		d._play(key, volume_db)


static func play_at(tree: SceneTree, key: StringName, at: Vector2, volume_db := 0.0) -> void:
	var d := _find(tree)
	if d != null:
		d._play_at(key, at, volume_db)


## Contact blip key for a species and an AI state, e.g. "blip_crab_2".
static func blip_key(species: StringName, state: int) -> StringName:
	return StringName("blip_%s_%d" % [species, state])


## Cry key for a species and an AI state, e.g. "cry_hostile_fish".
static func cry_key(urgent: bool, species: StringName) -> StringName:
	return StringName("cry_%s_%s" % ["hostile" if urgent else "alert", species])


static func _find(tree: SceneTree) -> AudioDirector:
	if tree == null:
		return null
	return tree.get_first_node_in_group(GROUP) as AudioDirector


# --- Playback ----------------------------------------------------------------

func _play(key: StringName, volume_db: float) -> void:
	if muted or not _streams.has(key):
		return
	var player := _free_sfx()
	player.stream = _streams[key]
	player.volume_db = volume_db + GameConfig.VOL_SFX
	player.play()


func _play_at(key: StringName, at: Vector2, volume_db: float) -> void:
	if muted or not _streams.has(key):
		return
	var player := _free_pos()
	player.stream = _streams[key]
	player.global_position = at
	player.volume_db = volume_db + GameConfig.VOL_SFX
	player.play()


## Prefers a silent player over stealing one mid-sound, so a burst of pickups
## layers up instead of cutting each other off.
func _free_sfx() -> AudioStreamPlayer:
	for i in _sfx_pool.size():
		var candidate := _sfx_pool[(_sfx_next + i) % _sfx_pool.size()]
		if not candidate.playing:
			return candidate
	var fallback := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	return fallback


func _free_pos() -> AudioStreamPlayer2D:
	for i in _pos_pool.size():
		var candidate := _pos_pool[(_pos_next + i) % _pos_pool.size()]
		if not candidate.playing:
			return candidate
	var fallback := _pos_pool[_pos_next]
	_pos_next = (_pos_next + 1) % _pos_pool.size()
	return fallback


# --- Buses and mute ----------------------------------------------------------

## M. Mutes the master bus rather than the individual players, so the ambience
## loop, anything still playing, and anything started later are all covered by
## one switch.
func toggle_mute() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	if not muted:
		# Unmuting a stopped ambience loop would otherwise leave silence.
		_start_ambient()


func _start_ambient() -> void:
	if _ambient != null and _ambient.playing:
		return
	if muted or not _streams.has(&"ambient"):
		return
	if _ambient == null:
		_ambient = AudioStreamPlayer.new()
		_ambient.stream = _streams[&"ambient"]
		_ambient.bus = &"Ambience"
		add_child(_ambient)
	_ambient.play()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_mute"):
		toggle_mute()
		get_viewport().set_input_as_handled()


# --- Construction ------------------------------------------------------------

func _build_pools() -> void:
	for i in SFX_POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_sfx_pool.append(p)

	for i in POSITIONAL_POOL:
		var p2 := AudioStreamPlayer2D.new()
		p2.bus = &"SFX"
		# Audible across most of a sonar ping, so anything you can detect is
		# something you can hear.
		p2.max_distance = GameConfig.SONAR_MAX_RANGE
		p2.attenuation = 1.0
		p2.panning_strength = 1.4
		add_child(p2)
		_pos_pool.append(p2)


## Generated once, here, and never again: a sound is a few hundred kilobytes of
## buffer and there is no reason to pay for it per shot.
func _build_streams() -> void:
	_streams[&"ping"] = Sfx.ping()
	_streams[&"torpedo_launch"] = Sfx.torpedo_launch()
	_streams[&"torpedo_hit_flesh"] = Sfx.torpedo_hit_flesh()
	_streams[&"torpedo_hit_reef"] = Sfx.torpedo_hit_reef()
	_streams[&"damage"] = Sfx.damage()
	_streams[&"gold"] = Sfx.gold()
	_streams[&"ammo"] = Sfx.ammo()
	_streams[&"swim"] = Sfx.swim()
	_streams[&"game_over"] = Sfx.game_over()
	_streams[&"ambient"] = Sfx.ambient()

	# Enumerated rather than listed, so a new species is guaranteed a voice. The
	# previous hardcoded pair meant a creature missing from this line simply had
	# no sound at all, and nothing said so.
	for profile in Species.PROFILES:
		for state in [PASSIVE, ALERT, HOSTILE, FLEEING]:
			_streams[blip_key(profile.id, state)] = Sfx.contact_blip(profile, state)
		_streams[cry_key(false, profile.id)] = Sfx.cry_alert(profile)
		_streams[cry_key(true, profile.id)] = Sfx.cry_hostile(profile)