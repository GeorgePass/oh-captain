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
const CONTACT_DMG_COOLDOWN := 0.7
## Shove applied when something rams the hull, so contact is a hit-and-bump
## rather than a grind.
const CONTACT_KNOCKBACK := 90.0

# --- Audio ---
## Everything is synthesised at runtime, so these are the only mix controls.
## Individually trimmed on top of VOL_SFX, before bus volume.
const VOL_SFX := -4.0
const VOL_AMBIENCE := -20.0
const VOL_PING := -5.0
const VOL_BLIP := -13.0
const VOL_TORPEDO := -6.0
const VOL_ENEMY := -11.0
const VOL_DAMAGE := -4.0
const VOL_GOLD := -10.0

# --- Gold ---
## Coins drift toward the hull inside this radius, and are taken on contact.
const PICKUP_MAGNET_RADIUS := 130.0
const PICKUP_MAGNET_ACCEL := 900.0
const PICKUP_COLLECT_RADIUS := 26.0
const PICKUP_DRAG := 3.0
## Gold carried by a wreck, spread across a few coins.
const WRECK_GOLD_MIN := 6
const WRECK_GOLD_MAX := 22
## Chance a wreck holds any gold at all.
const WRECK_GOLD_CHANCE := 0.65
const WRECK_COINS_MIN := 2
const WRECK_COINS_MAX := 5

# --- Sight ---
## How far the captain can actually see, and therefore how far they can lock on.
## Plain radial distance, no cone and no line-of-sight test. Sonar reaches far
## beyond this; locking deliberately does not, though a sonar contact also
## qualifies for lock regardless of distance.
const LOCK_VISUAL_RANGE := 560.0
## Extra distance past visual range where the lock-on grace window is still
## being refreshed, so loitering on the boundary does not make a target flicker.
const LOCK_RELEASE_MARGIN := 120.0
## How long a lock stays valid after leaving that band. Losing sight should cost
## you the lock eventually, but not on the frame it happens.
const LOCK_RELEASE_TIME := 8.0
## Hard cap, as a multiple of visual range. Past this the grace window cannot
## hold a lock at all, so a target that is genuinely gone is dropped at once.
const LOCK_RELEASE_HARD_MULT := 3.0

# --- Sonar ---
const SONAR_MAX_RANGE := 900.0
const SONAR_PING_SPEED := 720.0
## Gap between pings while the sonar is held on. Also the wait after switching
## it off and straight back on: the cooldown is not reset by the toggle.
const SONAR_COOLDOWN := 8.0
## How long a revealed enemy stays on the radar and lockable. Comfortably longer
## than the ping cooldown, so a continuous sweep does not flicker.
const SONAR_CONTACT_DURATION := 16.0
## How far off the true hull position a ping places an alerted enemy's search.
## Without this, searching a pinged area would walk straight to the player.
const SONAR_PING_SEARCH_SPREAD := 220.0
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

# --- Enemies ---
## Shared AI tuning. Fish and crabs differ in body stats, not behaviour, so the
## stealth rules stay legible: every enemy hears the same way.
const ENEMY_PASSIVE_SPEED := 32.0
const ENEMY_TURN_RATE := 4.0
const ENEMY_ACCEL := 5.5
## An ALERT enemy moves at a purposeful walk, well below a charge.
const ENEMY_ALERT_SPEED := 62.0
## Radius it sweeps around the last known position before giving up.
const ENEMY_SEARCH_RADIUS := 90.0
## An enemy at or below one third of its HP gives up and runs for it.
const ENEMY_FLEE_HP_DIVISOR := 3
## Fleeing speed, deliberately below the hull's top speed: a fish that bolts has
## to stay catchable, or a five HP fish becomes permanently unkillable.
const ENEMY_FLEE_SPEED := 130.0
## A nearly-dead fish bolts outright when something dies this close by.
const ENEMY_FLEE_PANIC_RADIUS := 260.0
const ENEMY_FLEE_PANIC_HP := 1
## How long it keeps searching before reverting to passive.
const ENEMY_ALERT_TIMEOUT := 7.0
## Swimming sounds, as a gap between rustles. This is how a creature you have
## not pinged can still give itself away.
const ENEMY_SWIM_MIN_GAP := 2.5
const ENEMY_SWIM_MAX_GAP := 6.5
## How far out a swimming sound is worth playing, as a multiple of earshot.
const ENEMY_SWIM_AUDIBLE_MULT := 2.2
## Gold and torpedoes dropped by a killed enemy.
const ENEMY_GOLD_MIN := 2
const ENEMY_GOLD_MAX := 6
const ENEMY_AMMO_CHANCE := 0.35
const ENEMY_AMMO_DROP := 4

## Fish: nimble and fragile. Quick to turn on you, dies to one torpedo, but
## barely scratches the hull.
const FISH_MAX_HP := 5
const FISH_CHARGE_SPEED := 175.0
const FISH_RADIUS := 13.0
const FISH_CONTACT_DMG := 4
const FISH_GOLD_MIN := 2
const FISH_GOLD_MAX := 5

## Crab: armoured and slow. Charges well below the hull's top speed, so it can
## always be shaken, but it takes three torpedoes and one hit hurts.
const CRAB_MAX_HP := 30
const CRAB_PASSIVE_SPEED := 16.0
const CRAB_CHARGE_SPEED := 112.0
const CRAB_TURN_RATE := 2.0
const CRAB_ACCEL := 2.2
const CRAB_RADIUS := 26.0
const CRAB_CONTACT_DMG := 16
const CRAB_GOLD_MIN := 12
const CRAB_GOLD_MAX := 20

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
