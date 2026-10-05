# Three Paths

How many people you get out of a stage decides where you go next: hero, neutral
or dark, worked out at the exit, Shadow the Hedgehog style.

**Status:** M1, M2 and M3 are built — the outcome rule, the exit, the objectives
panel, the stage graph, the router and per-path populations. What's left is
endings, content and the two jobs in [§11](#11-everything-still-to-do), which
also lists every stage and system still outstanding.

This file is the canonical copy. There's a formatted version at
<https://claude.ai/artifact/GYPDRgz3g2tnVYUiH7xNNa> that will drift; trust this one.

---

## 1. The rule

Every civilian ends a stage in one of three states: **saved** (you reached them
and got them out), **died**, or **untouched** — alive, but you never helped them.
The outcome is read when you touch the stage exit.

| Path | Rule | What it feels like |
| --- | --- | --- |
| **Hero** | `saved == total` | Everyone out alive. The slowest route, and the one the alert level punishes. |
| **Dark** | `died >= total / 2` | Half the stage or more died while you were busy with something else. |
| **Neutral** | anything else | You went through. People you never met are still alive. |

Neutral is the default rather than something you aim at. Clearing a stage fast
*is* the neutral route: a danger clock only starts when that civilian comes on
screen, so a player who never slows down leaves a stage full of living strangers.

Worked through the greybox, which has three civilians:

| Run | Saved | Died | Outcome |
| --- | --- | --- | --- |
| Dex, Ada and Juno all out | 3 | 0 | Hero |
| Straight to the exit, nobody seen | 0 | 0 | Neutral |
| Ada saved, Juno's clock ran out | 1 | 1 | Neutral |
| Fought through Room E, Juno and Dex died | 1 | 2 | Dark |

Three civilians makes every single person a third of the outcome. Five or six per
stage gives the thresholds room to breathe.

## 2. Dark, without letting the player shoot civilians

Civilians take no damage from the hero, ever. There is no button that kills a
bystander, and a stray shot in a crowded room is not a punishment. Dark is
something you let happen, not something you aim at.

The collateral case still works, because everything *except* the hero can kill
them:

| Cause | Reads to the player as |
| --- | --- |
| A danger clock runs out | "I didn't get there in time." |
| Enemy fire and enemy explosions | "I fought next to them and they were hit." |
| Stage hazards: crushers, fire, flooding | "I left them in that room." |

The second line is the collateral case: the player who chases the villain through
a room full of people, with enemies firing at a moving target, loses them. No new
weapon behaviour is needed — enemies already fire at the hero, and their shots
already miss.

> **Decision to confirm.** This reads "civilians can't be harmed by you" as
> immune to *the hero's* attacks, not invulnerable in general. If the team wants
> them untouchable in combat entirely, dark comes down to clocks alone and the
> collateral reading goes away.

## 3. What the player sees

A branch nobody can see is a lottery. The HUD gets a third block listing all
three outcomes at once, with the one you're currently on track for marked:

```
                                        SAVED 2/3
                                        LOST  1
                                        G _ _ _ _ _ _
                                        [#][#][ ] ALERT

                                        THIS RUN
                                        | HERO     3/3      (greyed out)
                                        | NEUTRAL  <--
                                        | DARK     2 DIE
```

When an outcome becomes impossible — the first death kills the hero route — its
line greys out immediately. Knowing you've lost the hero path mid-stage is
information, and it's the moment a player decides whether to go back for the last
person or write the run off.

## 4. Two systems, not one

Rescues and upgrades are doing two different jobs, and they should be two systems
that share nothing but the `Upgrade` resource format.

| | **Upgrade caches** | **Civilians** |
| --- | --- | --- |
| Job | reward exploration | express morality |
| How | touch to collect, hidden off the critical path | interact to free, danger clock, counted |
| Gives | an ability, a stat, or a letter | nothing mechanical — the branch *is* the reward |
| Feels like | Mega Man's heart tanks | the point of the game |
| Scene | `src/items/upgrade_cache.tscn` (new; the reference branch's `pickup.gd` is most of it) | `src/rescue/civilian.tscn` (exists) |

What changes in the current code is small: `Civilian` loses its `upgrade` and
`letter` exports, and those move to the cache scene. The tracker, `GameState`,
`apply_upgrades()` and the save file all stay as they are.

**Named survivors still matter — they just pay in story, not power.** Ada can
still be the engineer you remember; she unlocks a scene, a line of dialogue on
the stage select, an ending flag. The moment she hands over a damage upgrade,
the hero path becomes the optimal path and the moral choice stops being a choice.

### How many upgrades does that actually need?

Upgrade count is now independent of level count, because caches are placed where
you want them rather than one per rescued person. A whole-game budget:

| | Count | Notes |
| --- | --- | --- |
| Abilities | 4 | air dash, double jump, hook boost (all built), plus one more — wall cling is the obvious gap |
| Stat upgrades | 4–6 | health ×2, charge rate, i-frames, maybe weapon energy |
| Letters | 8 | G-U-A-R-D-I-A-N, together unlocking one reward |
| **Total hidden things** | **16–18** | across ~22 stages |

Not dozens. Most stages hold one cache, one letter, or nothing at all.

**The placement rule that matters:** because a run only sees part of the tree,
each *path* needs a comparable share of the caches. If the hero branch holds
every ability, the dark branch is strictly weaker and nobody picks it twice.
Count caches per branch, not per game.

## 5. The stage graph

Each stage names three successors. Three branches from every stage with no
convergence is impossible — the tree needs `(3^depth - 1) / 2` stages:

| Depth | Stages, no convergence |
| --- | --- |
| 2 | 4 |
| 3 | 13 |
| 4 | 40 |
| 5 | 121 |

So paths converge: **branch, branch, rejoin**. One act is eight stages:

```
                     [ ROOFTOPS ]  -->  [ SKY SPIRE ]
                    / hero                          \
 [ FOUNDRY ] ------>  [ TRANSIT ]  -->  [ CHANNEL ] --->  [ CITADEL ]
   opening          \ neutral                          /    everyone
                     [ UNDERCITY ] --> [ CANYON ]     /      arrives
                      dark
```

- 1 act: 8 stages
- 2 acts: 15 (the hub becomes the next act's opening)
- 3 acts: **22**

Which lands on the 20–25 you estimated. A run through three acts plays about 12
of those 22, so a player sees roughly half the game per run, and replaying is
how the rest shows up. That's the structure working, not a waste — but it means
the opening act is seen by everyone and deserves the most polish.

**Reuse cuts the real cost.** A tier-2 stage can be a *variant* of its tier-1
geometry rather than a new level: same rooms, different population and a
different route through them. That makes an act cost about 6.5 levels of work
instead of 8, so three acts is roughly 18 levels of work for 22 slots.

The graph is data, not code: one resource listing each stage and its three
successors, so the shape changes without touching a script.

## 6. The same stage, two runs

Paths also change how a stage is populated, which is what keeps the level count
sane. One scene, three populations, chosen by the path you arrived on — node
groups in the level enabled on load.

| Arriving on | Civilians | Enemies | Alert |
| --- | --- | --- | --- |
| Hero | more, further off the critical path | standard | starts at 0 |
| Neutral | standard | standard | starts at 0 |
| Dark | fewer, in worse places | denser, more turrets and crossfire | starts at 1 |

A dark run should feel like a city that has stopped expecting help. That reads
through enemy density and who's left standing around, not through a palette swap.

## 7. What gets remembered

`GameState` already saves per-stage records, letters and upgrades to
`user://progress.json`. Branching adds two fields: each stage's outcome, and the
order they happened in — `["H", "N", "N", "D"]` — which is what the ending reads.

> **A rule that has to change.** Today a replay can only improve a stage's
> record, so going back for someone you missed is never a risk. With branching,
> the *latest* run has to decide the branch, or a player who first cleared a
> stage as hero could never choose the dark route afterwards. Split the two: the
> most recent outcome drives the path, a lifetime best stays for stats and for
> letters already collected.

## 8. Build order

The shape of the work is: prove the loop in one level, prove the routing with
empty levels, then make content. Content is the long pole, and it can't start
until levels are interchangeable.

### M1 — One stage, three outcomes — **done**

No new levels, no routing. The greybox has an exit, and reaching it reports
hero, neutral or dark.

- `StageGoal`: an exit area that ends the run
- Outcome worked out from the tracker's counts
- Objectives panel on the HUD, impossible routes greyed out
- Civilians killable by enemy fire and hazards, not by the hero
- A test suite per outcome

### M2 — The graph, with stubs — **done**

Routing proven before any content exists.

- `src/core/stage_graph.tres`: stage id -> {hero, neutral, dark} successor, display name
- `SceneRouter` lifted from the `reference/full-framework` branch (fades and scene swapping)
- Outcome and path history saved and reloaded
- Seven stub levels, generated by `tools/gen_stubs.gd`
- `tools/tests/test_graph.gd` walks the graph; `tools/tests/smoke_route.gd` walks
  it for real, loading each scene

### M3 — Populations — **done**

One stage, three ways to play it, chosen by the path you walked in on.

- `src/level/population.gd`: a group of nodes that only exists on some arriving
  paths. It culls in `_enter_tree`, before its children ever enter the tree, so
  they never join the `civilians` or `enemies` groups and never reach the
  tracker's count
- `GameState.arrived_as`: the outcome that brought you here, saved with the rest
- The greybox varies: a hero arrival finds Wen in the gallery, a dark arrival
  finds Juno already gone and four more enemies in the way
- `Alert.dark_start_level`: a dark arrival opens at alert 1
- Dev keys F6 / F7 / F8 replay the current stage as a hero / neutral / dark arrival
- `tools/tests/test_populations.gd`

### M4 — Endings

The path history picks an ending. 3 acts x 3 outcomes is 27 histories; map them
to five or six endings by majority, with the final act weighted heaviest.

### How levels plug together

Every level is interchangeable, because the router has to be able to load any of
them the same way. The contract:

| Every level scene has | Why |
| --- | --- |
| a `Level` root script | the router talks to this and nothing else |
| a `PlayerSpawn` marker | the router spawns the player, the scene doesn't own them |
| one or more `StageGoal` exits | ends the stage and reports the outcome |
| a `RescueTracker` | counts the civilians in it |
| an `Alert` | the stage's own clock |
| `Pop_H` / `Pop_N` / `Pop_D` groups (optional) | per-path population, M3 onward |

Levels never reference each other. A level knows its own `stage_id` and nothing
about what comes next — the graph owns that. This is what lets the team build
levels in parallel, and what lets the graph be rearranged without touching them.

## 9. Still open

- **How many civilians per stage?** Three prototypes fine; five or six is better
  for thresholds.
- **Do untouched civilians sit right with you?** Running past everyone for a
  clean neutral is the design working as written. It should feel like
  indifference, not a loophole.
- **Do enemies ever target civilians deliberately?** Cheap to add, and it turns
  dark from neglect into something the villain does while you watch.
- **Does the dark path need a mechanical reason to exist?** Right now it's the
  fast route. Fast is a real reason, but it may not be enough.
- **How many endings?** Three is the honest minimum; Shadow shipped ten.
- **Is progress per-run or permanent?** Letters and upgrades carrying across runs
  makes replaying the tree feel like progress rather than a reset.

## 10. Where this is up to

### Built in M1

| Piece | Where |
| --- | --- |
| Hero / neutral / dark rule | `src/rescue/rescue_tracker.gd` — `outcome()`, `outcome_code()`, `hero_possible()`, `dark_possible()`, `neutral_possible()`, `deaths_for_dark()` |
| The exit | `src/level/stage_goal.gd` + `.tscn`, in the greybox at the far end of Room E |
| Objectives panel | `src/ui/hud.gd` — `_draw_objectives()`, with the cleared banner in `_draw_result()` |
| Civilians harmable by enemies only | physics layer 9 `civilian`; `src/rescue/civilian_hitbox.gd`; masks in `projectile.gd` and `blast.gd` |
| Civilian health and death cause | `src/rescue/civilian.gd` — 6 HP, `Cause.CLOCK` / `Cause.CAUGHT_IN_FIRE` |
| Outcome saved | `src/autoload/game_state.gd` — `record_outcome()`, `outcome_of()`, `outcome_sinks path_history` |
| Tests | `tools/tests/test_outcomes.gd`, 30 checks |

Numbers worth tuning by feel, all exported: `dark_share` (0.5) on the tracker,
`max_health` (6) and `danger_time` on each civilian, `hold_player` on the goal.

### Deliberately not done in M1

- **Hazards.** Civilians can be killed by enemy fire; there are no spikes or
  crushers in the greybox to kill them with yet.
- **A result screen.** Reaching the exit freezes the hero and shows a banner.
  There's nowhere to go next until M2.
- **Enemies aiming at civilians.** Still an open question in §9.

### Built in M2

| Piece | Where |
| --- | --- |
| The graph | `src/core/stage_graph.gd` + `stage_graph.tres` — eight stages, each naming three successors |
| Scene changes | `src/autoload/scene_router.gd` + `.tscn`, autoloaded as `SceneRouter` |
| The goal travels | `src/level/stage_goal.gd` — looks up `next_stage_id`, holds the result on screen for `result_time`, then routes |
| Seven stub levels | `levels/rooftops|transit|undercity|sky_spire|deep_channel|scrap_canyon|citadel.tscn`, from `tools/gen_stubs.gd` |
| Tests | `test_graph.gd` (26 checks, no scene changes) and `smoke_route.gd` (walks a real run) |

The graph as it stands: the greybox branches to rooftops / transit / undercity,
those branch again, and everything converges on the citadel. A run is four
stages. Rearranging it means editing one `.tres`.

### Deliberately not done in M2

- **The `Level` root script and `PlayerSpawn` from §8.** The stubs copy the
  greybox instead: each level embeds its own Player, camera and HUD. That works
  with `change_scene_to_file` and kept M2 small, but it means every level repeats
  that wiring. Worth doing properly before there are twenty of them.
- **Entering a stage knowing which path you came in on.** `GameState.path_history`
  has it; nothing reads it yet. M3 needs it.
- **A result screen.** The outcome shows as a HUD banner for two seconds, then
  the next stage loads.

### Built in M3

| Piece | Where |
| --- | --- |
| Per-path populations | `src/level/population.gd`, groups named `Pop_Hero` / `Pop_HeroNeutral` / `Pop_Dark` |
| The arriving path | `GameState.arrived_as`, set when the previous stage was counted, saved with the run |
| Varied greybox | `tools/gen_level.gd` — `_populations()` |
| Varied stubs | `tools/gen_stubs.gd` — a hero arrival adds a witness, a dark one adds two walkers |
| Alert head start | `src/rescue/alert.gd` — `dark_start_level` |
| Dev keys | F6 / F7 / F8 reload the stage as a hero / neutral / dark arrival |
| Tests | `tools/tests/test_populations.gd` |

The greybox, counted three ways:

| Arriving on | Civilians | Enemies | Alert |
| --- | --- | --- | --- |
| nothing (played on its own) | 3 | 10 | 0 |
| Hero | 4 (Wen is in the gallery) | 10 | 0 |
| Neutral | 3 | 10 | 0 |
| Dark | 2 (Juno's clock ran out before you got here) | 14 | 1 |

## 11. Everything still to do

### Milestones

| | What | Blocked on |
| --- | --- | --- |
| **M4** | Endings: the path history picks one of five or six | nothing — can be built now |
| **M5** | Content: turning 7 stubs into real stages | the two jobs below |

### Two jobs before real content

**The upgrade/cache split (§4).** Civilians still carry `upgrade` and `letter`;
there's no cache scene. Until that's split, upgrades can't be spread across the
three paths, so the hero route holds all the power and the branch isn't a real
choice. Small now, painful once seven levels have content placed in them.

**The level contract (§8).** Every level — the greybox and all seven stubs —
embeds its own Player, camera and HUD, copied from the greybox. A `Level` root
script with a `PlayerSpawn` marker would own that once. Twenty levels repeating
it is twenty places to edit when any of it changes.

### Stages

All eight exist and route correctly. Only the greybox has content.

| Stage | Act | Reached by | State |
| --- | --- | --- | --- |
| `greybox` (Foundry District) | opening | start of the run | real content, no boss |
| `rooftops` | 1 | hero | stub |
| `transit` (Midnight Transit) | 1 | neutral | stub |
| `undercity` | 1 | dark | stub |
| `sky_spire` (Sky Refinery) | 2 | hero-ish routes | stub |
| `deep_channel` | 2 | mixed routes | stub |
| `scrap_canyon` | 2 | darker routes | stub |
| `citadel` (Citadel Core) | hub | everyone | stub, and the run ends there |

Three acts of this shape is ~22 stages (§5). Acts 2 and 3 aren't in the graph
yet: the citadel currently ends the run, and becomes the next act's opening when
there is one.

### Systems not built at all

Ordered roughly by how much the design above depends on them.

| System | Why it matters | Notes |
| --- | --- | --- |
| **Bosses** | every act needs one, and the alert level is supposed to make them harder | `reference/full-framework` has `boss.gd`, `boss_arena.gd` and a finished boss to borrow |
| **Upgrade caches** | §4; the balance of the three paths | reference `pickup.gd` is most of one |
| **Hazards** | the third way civilians die (§2), and level variety | reference has `hazard.gd` |
| **Endings** | M4; what the path history is *for* | reference has `ending.gd` |
| **Menus, pause, game over** | a game you can start and lose | reference has all three |
| **Save slots** | one save file today, no file select | reference has `save_system.gd` with three slots |
| **Lives and continues** | death currently just respawns you at a checkpoint | |
| **Stage select** | branching may not want one at all — the graph decides where you go | decide before building |
| **Enemies targeting civilians** | would turn dark from neglect into something the villain does | open question in §9 |
| **A result screen** | the outcome is a HUD banner for two seconds | |
| **Music** | the audio pack has four tracks sitting unused | |

### Known rough edges

- Killed enemies don't come back when you respawn at a checkpoint.
- The run has no end: the citadel's successors are empty, so you stop there.
- `path_history` grows forever; it needs clearing when a run starts (M4's job).
- Replaying a stage re-appends to `path_history`, so the ending will read a
  longer history than the run actually was. Same fix.
- Nothing shows which path you arrived on while you play it — you can only tell
  from who's there.
