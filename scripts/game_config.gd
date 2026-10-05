class_name GameConfig
extends RefCounted
## Central tuning + physics layer constants for Oh Captain.
##
## Referenced from other scripts as `GameConfig.<NAME>`. Kept dependency-free
## so it can be pulled in from anywhere without load-order surprises.

# --- Physics layers (bit values for collision_layer / collision_mask) ---
const LAYER_PLAYER_BIT := 1 << 0    # 1
const LAYER_ENEMY_BIT := 1 << 1     # 2
const LAYER_REEF_BIT := 1 << 2      # 4
const LAYER_TORPEDO_BIT := 1 << 3   # 8

## Player collides with reefs and fish bodies.
const PLAYER_MASK := LAYER_ENEMY_BIT | LAYER_REEF_BIT
## Fish collide with reefs and are blocked by the player hull.
const ENEMY_MASK := LAYER_PLAYER_BIT | LAYER_REEF_BIT
## Reefs are pure static geometry.
const REEF_MASK := 0
## Torpedoes hit fish and are stopped by reefs.
const TORPEDO_MASK := LAYER_ENEMY_BIT | LAYER_REEF_BIT

# --- World ---
const WORLD_SIZE := 3000.0
const WORLD_HALF := WORLD_SIZE * 0.5

# --- Player ---
## Deliberately sluggish. Thrust and drag are both small, so the hull takes
## many seconds to reach speed and coasts for just as long once you let go;
## turning the nose does not redirect the boat, only the thrust vector.
const PLAYER_MAX_HP := 50
const PLAYER_MAX_AMMO := 20
const PLAYER_THRUST := 150.0
## Astern is far weaker than ahead, as on a real boat with one screw.
const PLAYER_REVERSE_THRUST := 70.0
const PLAYER_TURN_RATE := 1.6
## Multiplied by 120 to get the deceleration in px/s^2 (~42).
const PLAYER_DRAG := 0.35
const PLAYER_MAX_SPEED := 150.0
const PLAYER_RADIUS := 15.0
const FIRE_COOLDOWN := 0.45
## Speed above which the hull is considered to be sprinting, and can be heard
## at roughly twice the normal detection radius. High enough that only a real
## run triggers it, so creeping along stays quiet.
const FAST_SPEED := 110.0

# Contact damage: noticeable, but survivable through several mistakes.
const REEF_CONTACT_DMG := 14
const ENEMY_CONTACT_DMG := 9
const CONTACT_DMG_COOLDOWN := 0.7

# --- Sonar ---
const SONAR_MAX_RANGE := 900.0
const SONAR_PING_SPEED := 720.0
const SONAR_COOLDOWN := 3.0
const SONAR_CONTACT_DURATION := 4.0
## Fish this close are picked up by the passive hydrophone set, no ping needed.
const SONAR_PROXIMITY_RADIUS := 180.0
const SONAR_FAST_ENEMY_SPEED := 150.0
const SONAR_BLIP_MIN := 6.0
const SONAR_BLIP_MAX := 14.0
const SONAR_BLIP_DURATION := 1.2

# --- Stealth ---
## Earshot. Only fish this close notice the hull at all, and only if nothing
## solid is in the way.
const FISH_EARSHOT_RADIUS := 110.0
## How much further a sprinting hull carries. Sprinting is the tradeoff: pace
## for concealment.
const FISH_EARSHOT_SPRINT_MULT := 2.2
## The hull must stay inside earshot this long before a fish commits. Lets you
## slip past a patrol if you go quiet, and punishes loitering in the open.
const FISH_ALERT_DELAY := 0.9
## Reefs block sound as well as sight: a fish will not hear you through one.
const FISH_HEARING_BLOCKED_BY_REEF := true

# --- Fish ---
## Fish are nimbler than the hull: they accelerate and stop harder, but their
## top speed stays under PLAYER_MAX_SPEED, so you can always outrun one.
const FISH_MAX_HP := 5
const FISH_PASSIVE_SPEED := 32.0
const FISH_CHARGE_SPEED := 175.0
const FISH_TURN_RATE := 4.0
## Higher than the player's response rate, per the brief.
const FISH_ACCEL := 5.5
const FISH_RADIUS := 13.0

# --- Torpedo ---
## Scaled down with the hull so it still outruns the boat it came from.
const TORPEDO_SPEED := 330.0
const TORPEDO_DAMAGE := 10
const TORPEDO_LIFETIME := 5.0
const TORPEDO_TURN_RATE := 1.6
const TORPEDO_SPAWN_OFFSET := 34.0
const TORPEDO_RADIUS := 5.0


## Returns `pts` with its first vertex repeated at the end, for draw_polyline.
static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append_array(pts)
	if out.size() > 0:
		out.append(out[0])
	return out
