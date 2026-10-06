class_name Species
extends RefCounted
## One definition per kind of creature, and the only place it is written down.
##
## This replaces six places that each held their own partial idea of what a
## species is: the spawner's table, a hardcoded list in the audio director, a
## species-name test in each of three sound generators, and an `is EnemyCrab`
## branch in the radar. Those disagreed silently — a creature missing from the
## audio list simply had no voice, and one missing from a `species == &"fish"`
## test inherited the crab's.
##
## A new species is one Profile below plus a script that extends SeaEnemy for
## its `_draw`. Nothing else needs editing, and nothing can fall through to the
## wrong defaults because there are no defaults to fall through to.
##
## A creature is handed its Profile by whoever creates it, rather than declaring
## an id and looking itself up here. That used to be a second, independent
## statement of the same fact, and it is precisely the kind of thing that agrees
## until the day someone adds a third creature and is in a hurry.

## Identity, spawning and presentation for one species. An object rather than a
## dictionary entry, so a misspelled key is a compile error instead of a null
## that silently means zero.
class Profile extends RefCounted:
	var id: StringName
	## Scene to instantiate and the node it is parented under. Kept as a path so
	## this file stays free of load-order surprises; the spawner resolves it.
	var scene_path: String
	var container: StringName
	## What the water holds, and the cap it refills to. One number, so the
	## density the game was tuned at is the density it returns to.
	var population: int

	## Voice, as numbers rather than a flag. A third creature is then a third
	## pitch instead of a third accidental copy of one of the first two.
	var blip_hz: float
	## Applied to the blip when the creature has committed to a fight. Slightly
	## different per species so the same gesture reads differently.
	var blip_hostile_scale: float
	var cry_alert_hz: float
	var cry_hostile_hz: float
	## How far the hostile cry falls as it plays. Lower and slower reads heavier.
	var cry_hostile_sweep: float

	## Radar dot halo, in pixels. Zero draws a plain dot; anything else reads as
	## heavier at a glance, which is how a crab announces itself before you have
	## resolved what it is.
	var radar_halo: float


## Every species the game knows about. The spawner and the audio director both
## enumerate this, which is what stops them drifting apart.
static var PROFILES: Array[Profile] = []


static func _static_init() -> void:
	PROFILES = [_fish(), _crab()]


## Nimble and fragile. Dies to one torpedo, barely scratches the hull, and
## gives up on the first sign of trouble. High and quick on the ear.
static func _fish() -> Profile:
	var p := Profile.new()
	p.id = &"fish"
	p.scene_path = "res://scenes/fish.tscn"
	p.container = &"Fish"
	p.population = 9
	p.blip_hz = 1150.0
	p.blip_hostile_scale = 0.62
	p.cry_alert_hz = 620.0
	p.cry_hostile_hz = 1300.0
	p.cry_hostile_sweep = 0.55
	p.radar_halo = 0.0
	return p


## Armoured and slow. Takes three torpedoes and one hit really hurts. Low and
## unhurried on the ear, so it can be picked out from a shoal of fish you never
## saw.
static func _crab() -> Profile:
	var p := Profile.new()
	p.id = &"crab"
	p.scene_path = "res://scenes/crab.tscn"
	p.container = &"Crabs"
	p.population = 3
	p.blip_hz = 380.0
	p.blip_hostile_scale = 0.72
	p.cry_alert_hz = 240.0
	p.cry_hostile_hz = 300.0
	p.cry_hostile_sweep = 0.35
	p.radar_halo = 7.5
	return p