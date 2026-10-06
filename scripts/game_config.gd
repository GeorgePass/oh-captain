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
const WORLD_SIZE := 4200.0
const WORLD_HALF := WORLD_SIZE * 0.5

## The one number the whole run hangs off.
##
## Every random draw in the game comes from a generator seeded off this, never
## from the global dice. That is the difference between "I changed a speed and
## the fish got slower" and "I changed a speed and something I could not see also
## changed". With the global dice underneath, a tuning pass is measuring your
## change plus noise you did not know was there, and the two are impossible to
## separate afterwards.
const WORLD_SEED := 20260905

# --- Harbour ---
## The harbour sits at the one point the wrap never moves, which makes it the
## only fixed thing in the world: the place you leave from, and the only place
## a dive can be ended on purpose.
const HARBOR_POSITION := Vector2.ZERO
## Solid footprint of the built structure, centred on HARBOR_POSITION. A
## rectangle rather than a reef blob, because this one was built.
const HARBOR_SIZE := Vector2(420.0, 170.0)
## How close the hull has to be before the dock key does anything.
const HARBOR_DOCK_RADIUS := 330.0
## Keep-out for world generation, comfortably wider than the dock radius so the
## anchorage is clear water rather than a reef you have to squeeze past.
const HARBOR_CLEAR := Vector2(460.0, 380.0)
## Rejection-sampling budget for that keep-out. At about four per cent of the
## world this is a handful of redraws in practice; two hundred makes exhausting
## it a rounding error rather than a coin flip that quietly drops a reef on the
## only way in.
const HARBOR_CLEAR_ATTEMPTS := 200

# --- Oxygen ---
## Seconds of air in a full tank, and therefore the length of a dive. This is
## what gives going out to a wreck a cost: the distance is returnable, the clock
## is not.
const OXYGEN_MAX := 90.0
## Air burned per second. Frozen while the tree is paused, which is what docking
## does, so being alongside is the one moment the tank does not empty.
const OXYGEN_DRAIN := 1.0
## Once the tank is empty the hull starts losing integrity instead. Deliberately
## not routed through take_damage: drowning is not something striking the boat,
## so it carries no flash and no sound. This rate is what makes running out a
## problem worth turning around for rather than a slow way to lose.
const OXYGEN_DROWN_DPS := 4.0

# --- Pace ---
## One knob for the tempo of the whole game. Every speed below is a base value
## times this, so relative speeds are held by construction rather than by
## remembering to edit twelve numbers together. Turning the game up or down is
## a single edit.
const SPEED_SCALE := 0.75

# --- Player ---
## Deliberately sluggish. Accel and braking are expressed as *times* rather than
## forces: the hull takes PLAYER_ACCEL_TIME seconds to reach top speed from
## rest and PLAYER_BRAKE_TIME to fall from top speed to nothing. Both are long,
## and the glide down is longer than the run up, which is most of what makes it
## read as a submarine rather than a spaceship.
const PLAYER_MAX_HP := 50
const PLAYER_MAX_AMMO := 20
const PLAYER_MAX_SPEED := 150.0 * SPEED_SCALE
const PLAYER_ACCEL_TIME := 3.2
const PLAYER_BRAKE_TIME := 4.4
## Constant deceleration, so the coast is a straight line rather than an
## exponential tail that never quite arrives.
const PLAYER_DECEL := PLAYER_MAX_SPEED / PLAYER_BRAKE_TIME
## Drag always applies, so thrust is what the screw actually puts out and the
## difference between the two is what accelerates the hull. Stating the net
## figure is what makes ACCEL_TIME mean what it says on the tin.
const PLAYER_ACCEL := PLAYER_MAX_SPEED / PLAYER_ACCEL_TIME
const PLAYER_THRUST := PLAYER_ACCEL + PLAYER_DECEL
## Astern is far weaker than ahead, as on a real boat with one screw, so it takes
## more than twice as long to build way astern as it does to run ahead. The
## hull's ceiling is the same either way: astern is weaker because the screw is
## weaker, not because the boat somehow goes faster backwards.
const PLAYER_REVERSE_FRACTION := 0.47
const PLAYER_REVERSE_ACCEL := PLAYER_ACCEL * PLAYER_REVERSE_FRACTION
const PLAYER_REVERSE_THRUST := PLAYER_REVERSE_ACCEL + PLAYER_DECEL
## Direct steering of the nose only. The hull carries its momentum through a
## turn; spinning does not redirect it, only the thrust vector does.
const PLAYER_TURN_RATE := 1.6 * SPEED_SCALE
const FIRE_COOLDOWN := 0.45
## Speed above which the hull is considered to be sprinting, and can be heard
## at roughly twice the normal detection radius. High enough that only a real
## run triggers it, so creeping along stays quiet.
const FAST_SPEED := 110.0 * SPEED_SCALE

# Contact damage: noticeable, but survivable through several mistakes.
const REEF_CONTACT_DMG := 14
const CONTACT_DMG_COOLDOWN := 0.7
## Shove applied when something rams the hull, so contact is a hit-and-bump
## rather than a grind.
const CONTACT_KNOCKBACK := 90.0 * SPEED_SCALE

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

# --- Cargo ---
## Slot grid for the cargo panel: two across, four down. This is layout, not a
## cap on how many kinds of thing exist — widening the hold later is a change to
## these two numbers, and the panel sizes itself from them.
const INV_COLS := 2
const INV_ROWS := 4
const INV_CAPACITY := INV_COLS * INV_ROWS

# --- Shop ---
## The harbour counter. What each stack of cargo is worth lives on the item
## itself (Item.Def.value); these are the two things the counter sells that are
## not cargo. First-pass numbers — the captain tweaks them after playtest.
const TORPEDO_PRICE := 4
const REPAIR_PRICE := 12
## How much hull one repair bill restores. A chunk rather than the whole hull,
## so a repair is a judgement call and not a free full heal.
const REPAIR_AMOUNT := 25

# --- Refit bay ---
## The harbour's refit yard: five permanent buys for this run, each a stack of
## five levels. Buying level N (1-based) costs the base multiplied by the step
## (N-1) times, so the first buy is the base price and every further level
## costs more. Refits are for the dive you are on, not the next one: a restart
## tears the yard down with the rest of the run.
const REFIT_MAX_LEVEL := 5
## Base price and per-level multiplier, indexed by RefitBay.Track.
const REFIT_PRICE_BASE := [15, 20, 8, 26, 32]
const REFIT_PRICE_STEP := [1.8, 1.8, 1.7, 1.9, 1.9]
## What one level adds to the base reading, per track: seconds of air, hull
## points, torpedo slots, metres of sonar range, and a fraction of top speed.
const REFIT_OXYGEN_STEP := 45.0
const REFIT_HULL_STEP := 15
const REFIT_AMMO_STEP := 8
const REFIT_SONAR_STEP := 200.0
const REFIT_SPEED_STEP := 0.12

# --- Outpost ---
## The supply post on the far side of the water, a swim from home. It docks
## like the harbour and refills the tank, but sells nothing: its one errand is
## the harbourmaster's crate.
const OUTPOST_POSITION := Vector2(1600.0, 0.0)
## Solid footprint of the built structure, centred on OUTPOST_POSITION.
const OUTPOST_SIZE := Vector2(300.0, 130.0)
## How close the hull has to be before the dock key does anything.
const OUTPOST_DOCK_RADIUS := 260.0
## Keep-out for world generation, so the anchorage is clear water like the
## harbour's.
const OUTPOST_CLEAR := Vector2(340.0, 300.0)

# --- Missions ---
## The harbourmaster's three errands. Rewards are first-pass numbers; each is
## paid when the hull docks at the harbour with that mission's objective met.
const MISSION_REWARD_DELIVERY := 60
const MISSION_REWARD_KILL := 80
const MISSION_REWARD_RECOVER := 100
## How many fish the hunt asks for.
const KILL_MISSION_TARGET := 6
## Where the lost cargo went down. Fixed rather than seeded, like the outpost:
## everyone who takes the errand has to find the same wreck, and the marker on
## the radar has to point at a place that actually exists.
const MISSION_WRECK_POSITION := Vector2(-1500.0, 900.0)

# --- Sight ---
## How far the captain can actually see, and therefore how far they can lock on.
## Plain radial distance, no cone and no line-of-sight test. Sonar reaches far
## beyond this; locking deliberately does not, though a sonar contact also
## qualifies for lock regardless of distance.
##
## Scaled with the camera, so "what you can see" and "what you can lock" stay
## the same thing when the view changes.
const VIEW_SCALE := 1.333
const CAMERA_ZOOM := 1.6 / VIEW_SCALE
const LOCK_VISUAL_RANGE := 560.0 * VIEW_SCALE
## Extra distance past visual range where the lock-on grace window is still
## being refreshed, so loitering on the boundary does not make a target flicker.
const LOCK_RELEASE_MARGIN := 120.0 * VIEW_SCALE
## How long a lock stays valid after leaving that band. Losing sight should cost
## you the lock eventually, but not on the frame it happens.
const LOCK_RELEASE_TIME := 8.0
## Hard cap, as a multiple of visual range. Past this the grace window cannot
## hold a lock at all, so a target that is genuinely gone is dropped at once.
const LOCK_RELEASE_HARD_MULT := 3.0

# --- Sonar ---
## Reaches at least as far as the eye does, which is why the radar disc is
## sized off this number: the disk and the range scale together so the mapping
## from a contact to its dot stays constant.
const SONAR_MAX_RANGE := 900.0 * VIEW_SCALE
## Nudged up with the range so a ping still sweeps the whole disk in about a
## second and a half rather than crawling across it.
const SONAR_PING_SPEED := 720.0 * 1.1
## Gap between pings while the sonar is held on. Also the wait after switching
## it off and straight back on: the cooldown is not reset by the toggle.
const SONAR_COOLDOWN := 8.0
## How long a revealed enemy stays on the radar and lockable. Comfortably longer
## than the ping cooldown, so a continuous sweep does not flicker.
const SONAR_CONTACT_DURATION := 16.0
## How far off the true hull position a ping places an alerted enemy's search.
## Deliberately kept well inside ENEMY_SEARCH_RADIUS (90.0 against 120.0):
## a search narrower than its own error is a search of the wrong patch of water,
## so this used to stand off further than the creature was ever willing to walk,
## and it arrived, looked around from outside its own sight range, and gave up
## without finding anything. It still does not point at the hull — the player has
## had the whole approach to leave, which is what this protects.
const SONAR_PING_SEARCH_SPREAD := 90.0
## Fish this close are picked up by the passive hydrophone set, no ping needed.
const SONAR_PROXIMITY_RADIUS := 180.0 * VIEW_SCALE
const SONAR_FAST_ENEMY_SPEED := 150.0 * SPEED_SCALE
const SONAR_BLIP_MIN := 6.0
const SONAR_BLIP_MAX := 14.0
const SONAR_BLIP_DURATION := 1.2

# --- Stealth ---
# Sound and sight are two different questions with two different answers, and
# they are deliberately kept apart here. Sound is a bearing: it can point a
# creature at a noise and put it on ALERT, and it can never start a fight.
# Sight is distance held for a moment, and it is the only thing that ever makes
# a creature HOSTILE. Nothing that makes a noise is able to commit on its own.

## Earshot. Only creatures this close hear the hull at all, and only if nothing
## solid is in the way.
const FISH_EARSHOT_RADIUS := 110.0
## How much further a sprinting hull carries. Sprinting is the tradeoff: pace
## for concealment. It widens what they hear, never what they see — going fast
## tells them where to look, it does not let them see further than they could.
const FISH_EARSHOT_SPRINT_MULT := 2.2
## Reefs block sound: a fish will not hear you through one. They do not block
## sight, because there is no line of sight in this game — only distance — so a
## reef is cover from noise rather than from a creature close enough to look.
## The distinction earns its keep above earshot, where sprinting (242) is heard
## further than anything can be seen (110).
const FISH_HEARING_BLOCKED_BY_REEF := true

## Sight. Distance from the hull at which a creature can see it, and therefore
## the only thing that raises PASSIVE or ALERT to HOSTILE. Kept equal to
## earshot so that a creature close enough to hear is also close enough to see,
## but it is a separate number on purpose: one of them is about noise and the
## other is about being attacked.
const FISH_SIGHT_RADIUS := 110.0
## An alert creature is searching rather than drifting, so it is looking, and
## looking further is the entire difference between a searching enemy and a
## resting one. Without it a creature that walks to a pinged area looks around
## from further off than it thinks it has, gives up on arrival, and never finds
## the thing it was sent to investigate.
const FISH_SIGHT_ALERT_MULT := 1.6
## The hull must stay inside sight this long before a creature commits. Lets you
## slip past a patrol if you move, and punishes loitering in the open.
const FISH_SIGHT_DELAY := 0.9
## How far a torpedo launch carries. A launch is a bang rather than a rustle, so
## it reaches further than the hull's own noise does, and that is the price of
## firing: it hands a bearing to everything in range.
const ENEMY_LAUNCH_HEARING_RADIUS := 420.0

# --- Enemies ---
## Shared AI tuning. Fish and crabs differ in body stats, not behaviour, so the
## stealth rules stay legible: every enemy hears the same way.
const ENEMY_PASSIVE_SPEED := 32.0 * SPEED_SCALE
const ENEMY_TURN_RATE := 4.0 * SPEED_SCALE
const ENEMY_ACCEL := 5.5
## An ALERT enemy moves at a purposeful walk, well below a charge.
const ENEMY_ALERT_SPEED := 62.0 * SPEED_SCALE
## Radius it sweeps around the place it was last heard. Also, and on purpose,
## the radius that counts as having arrived: it is the working area around the
## sound, so a creature standing anywhere inside it is already looking at the
## right patch of water.
const ENEMY_SEARCH_RADIUS := 90.0 * VIEW_SCALE
## How fast that sweep turns, in radians per second. Slow enough to read as
## casting about rather than orbiting, and per-creature phased so a shoal does
## not fan out in step.
const ENEMY_SEARCH_SWEEP_RATE := 1.6
## An enemy at or below one third of its HP gives up and runs for it. Compared
## as a multiplication rather than `hp <= max_hp / 3`, because integer division
## rounds a third of a small animal down to nothing and quietly switches its
## nerve off.
const ENEMY_FLEE_HP_DIVISOR := 3
## Fleeing speed, deliberately below the hull's top speed: a fish that bolts has
## to stay catchable, or a five HP fish becomes permanently unkillable.
const ENEMY_FLEE_SPEED := 130.0 * SPEED_SCALE
## How close a death has to be before it draws attention. Bigger than the
## earshot that hides the hull in the first place, so a kill is heard well
## before the hull ever is.
const ENEMY_FLEE_PANIC_RADIUS := 260.0 * VIEW_SCALE
## How long it lingers at the place it was sent to look before drifting back to
## whatever it was doing. Counted from arrival, not from the moment it was
## alerted: a ping at maximum range buys the time to swim there instead of a
## fixed budget spent getting there, which is what used to make a long-range
## investigation die out halfway across the water.
const ENEMY_ALERT_TIMEOUT := 7.0
## Past this the hull stops being worth chasing or hiding from, and an alert or
## committed creature goes back to drifting. Set beyond the sonar on purpose: a
## ping at maximum range has to survive long enough to be investigated, or the
## radar would cancel its own discovery.
const ENEMY_GIVE_UP_RANGE := SONAR_MAX_RANGE * 1.5
## Swimming sounds, as a gap between rustles. This is how a creature you have
## not pinged can still give itself away.
const ENEMY_SWIM_MIN_GAP := 2.5
const ENEMY_SWIM_MAX_GAP := 6.5
## How far out a swimming sound is worth playing, as a multiple of earshot.
const ENEMY_SWIM_AUDIBLE_MULT := 2.2

## Fish: nimble and fragile. Quick to turn on you, dies to one torpedo, but
## barely scratches the hull.
const FISH_MAX_HP := 5
const FISH_CHARGE_SPEED := 175.0 * SPEED_SCALE
const FISH_CONTACT_DMG := 4

## Crab: armoured and slow. Charges well below the hull's top speed, so it can
## always be shaken, but it takes three torpedoes and one hit hurts.
const CRAB_MAX_HP := 30
const CRAB_PASSIVE_SPEED := 16.0 * SPEED_SCALE
const CRAB_CHARGE_SPEED := 112.0 * SPEED_SCALE
const CRAB_TURN_RATE := 2.0 * SPEED_SCALE
const CRAB_ACCEL := 2.2
const CRAB_CONTACT_DMG := 16

# --- Torpedo ---
## Scaled down with the hull so it still outruns the boat it came from.
const TORPEDO_SPEED := 330.0 * SPEED_SCALE
const TORPEDO_DAMAGE := 10
const TORPEDO_LIFETIME := 5.0
const TORPEDO_TURN_RATE := 1.6 * SPEED_SCALE
const TORPEDO_SPAWN_OFFSET := 34.0


## A generator that repeats instead of a fresh throw of the global dice.
##
## `salt` keeps unrelated draws off each other's sequence. Leave it at zero for a
## system with only one instance, such as the sonar.
static func seeded_rng(salt: int = 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = WORLD_SEED + salt
	return r


## The same, for anything placed in the water: reefs, coins and creatures.
##
## Salted by position rather than by instance id. A restart builds a fresh tree
## and hands out fresh ids, so an id-seeded world comes out identical on relaunch
## and different on Dive Again - which is precisely the comparison you make most
## often, so it is the one that has to hold. The spawner lays the water out the
## same way every dive, so position holds still where the id does not.
##
## One world unit per cell, finer than anything that reads it: two things sharing
## a stream would have to land within a pixel of each other.
static func seeded_at(p: Vector2) -> RandomNumberGenerator:
	var cell := Vector2i(roundi(p.x), roundi(p.y))
	return seeded_rng(cell.x * 73856093 ^ cell.y * 19349663)


## Folds one axis back into range.
##
## One step is always enough in both directions it is used. For a position that
## moves, the fastest anything travels is a small fraction of the world in a
## frame. For a difference between two points, the world is exactly one width
## across and both points are inside it, so the difference cannot exceed one
## width either.
static func _fold(v: float) -> float:
	if v > WORLD_HALF:
		return v - WORLD_SIZE
	if v < -WORLD_HALF:
		return v + WORLD_SIZE
	return v


## Folds a position back inside the world rectangle. The water wraps rather than
## ending, so anything that strays past an edge comes back out the far side
## instead of stopping at a wall.
static func wrap_position(p: Vector2) -> Vector2:
	return Vector2(_fold(p.x), _fold(p.y))


## The shortest way from `from` to `to` across the wrapped water.
##
## Subtracting positions gives the long way round whenever the two sit either
## side of a seam, which is why nothing in this game measures a distance or aims
## a vector with plain arithmetic. A hull at x = -2099 and a fish at x = 2099 are
## two pixels apart, not four thousand.
static func wrapped_delta(from: Vector2, to: Vector2) -> Vector2:
	var d := to - from
	return Vector2(_fold(d.x), _fold(d.y))


## Whether a reef sits between two points.
##
## Measured across the seam, so a reef just off the far edge still muffles what
## is happening right beside you. Both the hydrophone and the sonar ask this,
## and they used to keep separate copies of the same raycast.
static func reef_between(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2) -> bool:
	var to_there := wrapped_delta(from, to)
	if to_there.is_equal_approx(Vector2.ZERO):
		return false
	var query := PhysicsRayQueryParameters2D.create(
		from, from + to_there, LAYER_REEF_BIT)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not space.intersect_ray(query).is_empty()


## Returns `pts` with its first vertex repeated at the end, for draw_polyline.
static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append_array(pts)
	if out.size() > 0:
		out.append(out[0])
	return out
