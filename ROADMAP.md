# Oh Captain — Roadmap

Top-down 2D sonar-submarine, all UI synthesized in `_draw`. Godot 4.7,
GDScript only, zero external art or audio.

**Status: v2 prototype complete** — HEAD `3e35634` (harbor refit bay).
Three-mission structure, harbor/outpost economy, and ship upgrades are in
and live-verified. Working tree clean.

---

## What the prototype is

- Inertial boat with wrap-around edges, procedural reefs, fish and wrecks.
- Sonar stack: passive/active modes, expanding ping rings, lock-on, and a
  decaying-contact radar the HUD mirrors.
- Token economy alongside the sea itself: fish drop cargo, the harbor
  counter sells torpedoes and repairs and buys highlighted cargo, and the
  outpost takes deliveries and refills the tank.
- Three errands (one at a time, never aborted, paid on the return):
  DELIVERY, HUNT (kill counter "X/6"), WRECK recovery.
- Refit bay: five runs-scoped upgrades (OXYGEN / HULL / TORPEDO / SONAR /
  SPEED), prices scaling with level.
- Runs are terminal. Death ends a dive; restart reseeds the world.

## Deliberately not built (v2 scope)

- **No win condition.** The run has an end (death) but no goal earned.
- **No persistence.** Salvage, upgrades and missions live only in the run.
- **Missions are fixed constants** (`GameConfig.MISSION_*`), not a ladder.
- **One enemy archetype** under a state machine (hunt / drift / flee).

## v3 lanes (proposed, in the order the author wanted them)

### 1. Escalating mission structure
Replace the fixed three-errand roster with a ladder: each completed errand
unlocks the next tier, payouts and demands rise, and the roster densifies
as the run lengthens. The natural glue for the end-state (below):
- A ledger of "chalks this run" that survives until death rather than
  emptying at the outpost.
- Delivery targets that move further out; hunt targets that count more and
  meaner fish; recoveries that are not all parked on the map from frame one.
- The refit bay becomes the player's answer to a steeper slate — which is
  why it shipped before this lane.

### 2. More enemies and layered water
- New archetypes built on the existing state machine: a slow tank that
  takes several torpedoes, a fast jittering skimmer, a passive leviathan
  worth more salvage but dangerous to wake. Species already own their
  speed, sight, contact-damage and loot (`GameConfig` + `species.gd`) —
  the frame is there.
- Layered areas: depth/temperature bands that cost hull to cross raw, or
  reef-locked pockets that force a sonar choice. WORLD_SIZE and the
  wrap-around rule are the two constraints everything else bends around.

### 3. Bosses
- A set-piece enemy with phases — e.g. an armoured hull that sheds
  plating, a lure that is not a fish, a closing blind spot — tuned to make
  the refit bay matter rather than optional.
- A boss is also the cleanest way to close lane 1: "sink the boss that
  owns the sea" as the terminal objective.

### 4. The missing end state (ties 1–3 together)
Whatever form it takes, the win should be earnable only when the player
has both run-long progress (the ladder) and ship investment (the refit)
— otherwise one of the two systems proves decorative. Candidate: fully
refit the hull *and* clear the errand slate in the same run.

## Principles to keep

- Run-scoped state; no save file. If persistence ever ships, it changes
  the meaning of death and should be a deliberate design decision, not an
  ergonomic afterthought.
- Every new enemy stays literacy-relevant: what it can do must be readable
  from its silhouette, colour and behaviour (`sonar_display` colors are
  the vocabulary).
- Tuning lives in `GameConfig`; systems read it, never re-derive it.
- Missions/errands rules live in `MissionDirector`; no errand logic leaks
  into the harbor or outpost screens.