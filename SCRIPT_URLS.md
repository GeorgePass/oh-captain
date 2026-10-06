# Oh Captain — script list for external review

Repo: https://github.com/GeorgePass/oh-captain
Commit reviewed: 20ac102 (master)
Language: GDScript (Godot 4.7.2-stable)
Size: 19 scripts, ~2,418 lines

Use the `raw.githubusercontent.com` form. It returns plain source; the `blob`
form returns an HTML page and most agents will choke on the page chrome.

IMPORTANT: only the files below. The repo also contains `addons/godot_ai/`,
which is a third-party editor plugin (not game code) and is not part of the
review.

---

## Scripts (paste these)

https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scripts/game_config.gd
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scripts/species.gd
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scripts/main.gd
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scripts/spawner.gd
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scripts/player.gd
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scripts/sea_enemy.gd
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scripts/enemy_fish.gd
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scripts/enemy_crab.gd
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scripts/sonar.gd
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scripts/sonar_ring.gd
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scripts/sonar_display.gd
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scripts/torpedo.gd
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scripts/pickup.gd
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scripts/reef.gd
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scripts/wreck.gd
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scripts/hud.gd
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scripts/game_over.gd
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scripts/audio_director.gd
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scripts/sfx.gd
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scripts/blast.gd

## Supporting files (optional, for structure/context)

Scenes, which show the node tree, collision layers and HUD layout:

https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scenes/main.tscn
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scenes/player.tscn
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scenes/fish.tscn
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scenes/crab.tscn
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scenes/game_over.tscn
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scenes/sonar_ring.tscn
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scenes/torpedo.tscn
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scenes/reef.tscn
https://raw.githubusercontent.com/GeorgePass/oh-captain/master/scenes/wreck.tscn

Project settings, which carry the input map and physics layer names:

https://raw.githubusercontent.com/GeorgePass/oh-captain/master/project.godot

---

## Reading order, if the agent wants a sensible path in

game_config.gd      all tuning constants, one commented block per system
species.gd          one profile per creature: spawn data, voice, radar halo
main.gd             run root: death ripple, run end
spawner.gd          world generation + population replenishment
player.gd           movement model, lock-on, firing, contact damage
sea_enemy.gd        four-state AI, fleeing, per-enemy line-of-sight
enemy_fish.gd       fish stats + draw
enemy_crab.gd       crab stats + draw
sonar.gd            pings, contacts, cooldowns
sonar_ring.gd       one expanding ping
sonar_display.gd    radar HUD
torpedo.gd          steering, hits, impact
pickup.gd           salvage, magnet
reef.gd / wreck.gd  static geometry, drawn procedurally
hud.gd              vitals + buttons
game_over.gd        end screen
audio_director.gd   pooled procedural playback
sfx.gd              22 synthesised sound generators
blast.gd            radial impulse helper