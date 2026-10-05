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
const PLAYER_MAX_HP := 50
const PLAYER_MAX_AMMO := 20
const PLAYER_THRUST := 620.0
const PLAYER_REVERSE_THRUST := 340.0
const PLAYER_TURN_RATE := 3.0
const PLAYER_DRAG := 2.6
const PLAYER_MAX_SPEED := 420.0
const PLAYER_RADIUS := 15.0
const FIRE_COOLDOWN := 0.45
## Player speed above which nearby fish get alerted. Rewards slow, careful play.
const FAST_SPEED := 190.0

# Contact damage: noticeable, but survivable through several mistakes.
const REEF_CONTACT_DMG := 14
const ENEMY_CONTACT_DMG := 9
const CONTACT_DMG_COOLDOWN := 0.7

# --- Sonar ---
const SONAR_MAX_RANGE := 900.0
const SONAR_PING_SPEED := 720.0
const SONAR_COOLDOWN := 3.0
const SONAR_CONTACT_DURATION := 4.0
const SONAR_PROXIMITY_RADIUS := 260.0
const SONAR_FAST_ENEMY_SPEED := 150.0
const SONAR_BLIP_MIN := 4.0
const SONAR_BLIP_MAX := 9.0
const SONAR_BLIP_DURATION := 1.2
## Fish inside this radius always notice the player.
const SONAR_HOSTILE_RADIUS := 420.0

# --- Fish ---
const FISH_MAX_HP := 5
const FISH_PASSIVE_SPEED := 45.0
const FISH_CHARGE_SPEED := 230.0
const FISH_TURN_RATE := 3.0
const FISH_RADIUS := 13.0

# --- Torpedo ---
const TORPEDO_SPEED := 520.0
const TORPEDO_DAMAGE := 10
const TORPEDO_LIFETIME := 4.0
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
