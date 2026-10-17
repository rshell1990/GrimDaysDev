# GrimDays — Prototype

**GrimDays** is a work-in-progress Godot narrative RPG prototype. It combines a 3D, point-and-click visual-novel layer with branching Dialogic conversations, quests, time and location state, inventory and save systems, plus a separate data-driven, turn-based battle system.

The project currently identifies itself as **“GrimDays”**. It is a development snapshot rather than a finished release: editor-only debug scenes, older implementations, experimental systems, refactor work, and a large set of source assets are kept alongside the playable path. The repository includes a large content and source-asset library. Its on-disk size varies substantially depending on Git history and Godot's import cache.

## At a glance

- **Engine:** Godot 4.7 project features, Forward+ renderer and Jolt Physics; the connected editor reports `4.7.2-stable (official)`, with Spine supplied by the bundled GDExtension
- **Language:** GDScript
- **Target resolution:** 1920×1080 (`canvas_items` stretch mode)
- **Primary export:** Windows x86_64
- **Main scene:** `GrimDays/scenes/splash_screen.tscn`
- **Narrative tooling:** Dialogic 2
- **License:** MIT for the project code; bundled add-ons and media may have their own licenses

## Current flow

The configured startup scene plays the developer-logo video and then changes to the main menu. Starting a game launches the first event resource, `1_0000_start.tres`, and hands progression to the VN's event, Dialogic, navigation, and game-state systems.

Narrative content is organized as 47 numbered Dialogic timelines, from arrival in
Gerano through the siege of Novaras. The prototype now runs those timelines in
order rather than entering the unconfigured Childhood Home navigation screen
after Karak's room dialogue. The event master registers 50 events: 47 dialogue
scenes and three existing placeholder encounters. Existing event IDs and resource
UIDs are retained; old names referring to Celine's childhood/orphanage are
compatibility identifiers, not the current story setting.

Three encounter points reuse existing teams rather than introducing new enemies:

| Story encounter | Placeholder battle ID | Existing opponents | Continues to |
| --- | --- | --- | --- |
| Demorai return | `2_0035_fight_harlok_alone` | Harlok | Vera's conversation in Puran |
| Raiders and cave troll | `2_0032_fight_harlok_and_goons` | Harlok and both goons | Villagers reward the rescue |
| Lich and Ember Void blades | `2_0095_battle_with_nuns` | Hara, Katherine and Anastasia | Renia claims the blades |

Each prelude opens ordinary party preparation. The Delia/wagon scene applies the
existing level-3 floor to the persistent Celine placeholder ally without spending
the player's points. Harlok encounters require victory and support retries; the
three-nun encounter retains its existing accepted defeat branch. Continue on the
result summary loads a fresh story scene and resumes the ordered dialogue.
Other combat described in prose remains narrative-only; this is not new enemy
content, balance certification, or a complete location/background implementation.

Combat is its own resource-oriented subsystem. Unit templates, stats, equipment, skills, requirements, and effects are defined as Godot resources. Production story battles use `BattleCoordinator`, `BattleEncounterFlow` and `BattleTurnOrder` for encounter lifetime, player/AI choices and turn scheduling. Shared action and effect code resolves targeting, costs, damage and reactions. The numbered phase pipeline belongs to a separate legacy/debug route. Seeded random streams support repeatable tests when setup and action choices are the same. Presentation code displays resolved combat without applying damage again. `BattleResult` retains outcome and combat snapshots after attempt cleanup.

## Project structure

| Path | Purpose |
| --- | --- |
| `GrimDays/` | Application shell, splash screen, main menu, logo video, and shared production art under `assets/visuals/`. |
| `GrimDaysVN/` | Main narrative game: Dialogic content, locations, characters, UI, audio, shaders, data resources, and gameplay scripts. |
| `GrimDaysBattle/` | Turn-based combat implementation, battle scenes, unit/equipment/skill/effect resources, UI, and debug fixtures. |
| `addons/` | Vendored Godot editor and runtime plug-ins. |
| `GrimDays/imported/` | Shared or previously imported systems and assets, including scene management and UI helpers. |
| `editor_only_debug/` | Debug scenes, smoke-test suites, design notes, fixtures, and unused source visuals. Assets and runtime scripts required by production scenes live in the production folders. |
| `GrimDaysBattle/resources/skill_trees/` | Project-owned skill trees used by party preparation. |
| `project.godot` | Project settings, input map, autoloads, Dialogic registry, and enabled plug-ins. |
| `export_presets.cfg` | Windows Desktop export preset. |

### VN architecture

The VN code under `GrimDaysVN/scripts/` is split by responsibility:

- **Game state and global coordination:** managers, signal buses, system administrators, and persistent data.
- **Event flow:** event resources, requirements, actions, quests, and directors that move the story forward.
- **Dialogic integration:** commands, status, an administrator, and a relay between timelines and game systems.
- **Navigation:** locations, dimensions, interactable scenes, 3D maps, and navigation UI.
- **Presentation:** character operators, camera effects, layered scenes, UI, audio, animation, and VRAM-aware load-on-demand nodes.
- **Persistence and settings:** save/load tasks, preferences, display settings, played time, and first-run/options UI.

Many systems communicate through autoloaded managers and signal relays. `SystemHeadquarters` and the administrator hierarchy coordinate subsystem lifecycle; `GameManager` owns high-level modes such as navigation, scenario, battle, pause, loading, and UI overlays. The active `SaveAndLoadSystemManager` lives under `scripts/_a_major_refactor/save_and_load/`; that folder includes production code despite its name. Saves use integrity checks and staged replacement, and are blocked during battle handoffs, active encounters, reward acknowledgement and party preparation.

The event master's `called_events` list registers ID-only story events without
adding them to location/time schedules. The ordered prototype is registered there
under its existing and newly added IDs. Dialogue events use explicit
`GameEventSequence.finished_event` links and matching finishing timelines. They
continue in place with `blocks_swap`; only the opening cinematic and post-battle
returns need a new scene. Obsolete navigation, childhood quest/item operations
and world-range gates are not part of this rewritten linear narrative.
World-stage milestones are retained. Existing saved-state formats are unchanged,
but saves already stranded in the old empty navigation screen are not migrated:
restart the story or load a checkpoint before the room dialogue ends.

### Battle architecture

The battle code is under `GrimDaysBattle/scripts/`, organized by domain:

- `Unit/`, `Stats/`, `Actions/`, `Items/` and `Effects/` separate resource definitions from runtime implementations.
- `Battle/Runtime/` coordinates production encounters, rosters, turn order, story transitions, retries, recovery and reward settlement. `Battle/Presentation/` supplies production menus, stage routing and result/overflow panels.
- `Party/` owns persistent units, the shared stash and preparation sessions, including formation, equipment, attribute allocation and skill-tree access.
- `Skills/` defines project-owned trees, rank investments, action/passive chains, grants and preparation controls. Templates use `skill_collection`; Yggdrasil and its runtime bridge have been removed.
- `Phases/` contains the numbered phase pipeline; `UI/`, `Presentation/`, `Runtime/` and `_Global/` also contain shared and legacy/debug infrastructure. `Other/battle_result.gd` defines retained result snapshots.

Content under `GrimDaysBattle/resources/` supplies playable unit definitions, growth curves, stat collections, equipment, effects, and other authored data. The game-facing battle scenes remain under `GrimDaysBattle/scenes/`; focused debug scenes and fixtures are under `editor_only_debug/`.

The story scene registry resolves `battle` to `GrimDaysVN/scenes/root/battle.tscn`, which instances `GrimDaysBattle/scenes/battle/production_encounter.tscn`. The separate `GrimDaysBattle/scenes/battle/battle.tscn` is the legacy interactive debug fixture. The headless runner lives at `editor_only_debug/scripts/battle_headless_runner.gd`.

Accepted victories settle loot and experience once, handle shared-stash overflow through explicit player choices, recover party pools, and show a result summary before story continuation. Preparation is available from navigation's inventory button or explicit story calls, rather than during combat. Project-owned trees charge one shared skill point per purchased rank and support grants, preparation, save/restore and retry state. Celine's production collection includes five-rank Straight Punch and Control nodes. Harlok and the goons have separate empty collections. Invalid persisted investment is cleared with its derived grants, exposing earned points as unspent; legacy allocation conversion is not provided. Broader skill content and full balance acceptance remain unfinished. See [the battle implementation notes](GrimDaysBattle/scripts/Battle/README.md) for detailed contracts.

## Getting started

### Requirements

1. Use **Godot 4.7 with Forward+ support and the bundled Spine GDExtension loaded**. The 2026-09-23 editor connection reports `4.7.2-stable (official)` and exposes `SpineSprite`; a custom engine build is no longer required. The extension is configured in `bin/spine_godot_extension.gdextension` and needs a compatible library for the host platform. The project declares 4.7 features and may not open cleanly in older versions.
2. Clone or download the complete repository. Allow ample disk space for the large source-art library, Git history, and Godot's generated import cache.
3. Import `project.godot` from the Godot Project Manager.
4. Allow Godot to finish scanning and importing resources before running the game.

On Windows, the VS Code task **Godot: Open project in editor** opens this checkout
using Godot 4.7.2 from `%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64\`.
Run it through **Terminal > Run Task**. If the editor is moved, update the command
in [`.vscode/tasks.json`](.vscode/tasks.json) and the Godot Tools editor path in
[`.vscode/settings.json`](.vscode/settings.json).

GDScript add-ons are vendored in `addons/`, and Spine native libraries are bundled under `bin/`. The optional editor integration is **Godot AI 3.2.5** (`addons/godot_ai/`), exposed to MCP clients as `godot-ai`. Its standard server launch uses `uvx` and the Python `godot-ai` package; use the Godot AI dock to check setup and client connections. There is no checked-in root `.mcp.json` or Node.js/`npx` setup for the former MCP Toolkit.

### Run

Open the project in Godot and press **F6** to run the current scene or **F5** to run the configured project flow. From a shell with Godot on `PATH`:

```sh
godot --editor --path .
godot --path .
```

The command may be named `godot4` on some systems.

### Lint and validation

The Windows tooling requires PowerShell 5.1 or newer; no Python packages are needed.
Use **Terminal > Run Task** in VS Code:

- **Godot: Lint project** scans project-owned GDScript.
- **Godot: Lint current script** checks the active `.gd` file.
- **Godot: Validate project** runs the configured engine headlessly with
  `--editor --import`, reporting import and script compilation errors.
  Close this project's Godot editor first to avoid concurrent imports.
- **Godot: Test lint tooling** runs the linter's regression checks.

Equivalent PowerShell commands from the repository root:

```powershell
.\lint.ps1
.\lint.ps1 -Paths GrimDaysBattle
.\lint.ps1 -Paths path\to\script.gd -FailOnWarning
.\tools\test-lint.ps1
.\tools\validate-godot.ps1
```

[`lint.psd1`](lint.psd1) defines the scan roots, exclusions, and 120-character /
800-line advisory targets. Vendored `addons/`, imported helpers under
`GrimDays/imported/`, and generated `.godot/` files are excluded.
The linter never rewrites scripts. The 2026-10-06 cleanup established a clean
baseline across 665 scripts, using four-space indentation and coordinated
class/constant renames. Follow the [GDScript style guide](editor_only_debug/markdown_documentation/Project%20Documentation/Guidance/GDScript%20Coding%20Style%20Guide.md).

Tabs in indentation are errors; class/constant naming and breakpoints are warnings.
Length, whitespace, indentation alignment, Unicode identifiers, headers, prints,
and resource-loading checks are advisory. Comments and string contents are
excluded from executable-code checks. Intentional test output and runtime loading
remain valid; review these findings rather than blindly replacing them.
A finding can be suppressed on its own line with a reason, for example
`# lint:ignore debug-print -- Intentional smoke-test output.`
Reviewed exceptions retain test markers, runtime resource loading, indivisible
resource paths, authored UI text, and the cohesive unit lifecycle/save API.
These are deliberate exceptions, not disabled rules for entire directories.
Exit codes are **0** for no blocking findings, **1** for style errors (or warnings
with `-FailOnWarning`), and **2** for invalid input/tool failures.

Native validation uses the Godot Tools editor path in VS Code. From PowerShell,
override its downloaded-editor default with `-EnginePath C:\path\to\Godot.exe`.
It fails on engine errors even when Godot exits zero, and times out after
600 seconds (override with `-TimeoutSeconds`). Import validation is not a runtime
test or an exhaustive compile check of unused scripts; run the focused scene
checks below for behavioral verification.

### Export

The checked-in preset targets Windows Desktop x86_64. In the editor, use **Project → Export → Windows Desktop**. The stored export path is developer-specific, so choose a local destination before exporting.

From the command line, after installing matching Godot export templates, ensuring the target platform's Spine GDExtension library is available, and creating `build/`:

```sh
godot --headless --path . --export-release "Windows Desktop" ./build/Dreams-of-Celeste.exe
```

## Controls

The project and replay-recorder add-on provide these default inputs:

| Action | Default input |
| --- | --- |
| Advance/accept dialogue | Left click, Enter, Space, X, or gamepad south button |
| Back | Right click |
| Toggle menu | Right click or Escape |
| Toggle development performance display | F1 (`debug_toggle`) |
| Replay recorder | F11 (provided by the replay-recorder add-on) |

Some actions, including alternate menu, hide-textbox, and dialogue rollback, are declared without default bindings and can be configured through the game's input/settings systems.

## Development notes

- Follow the [GDScript Coding Style Guide](editor_only_debug/markdown_documentation/Project%20Documentation/Guidance/GDScript%20Coding%20Style%20Guide.md) when writing or generating project code. It covers formatting, naming, diagnostics and resource loading, including guidance for existing scripts.
- Start with `project.godot` to understand the autoload graph and enabled plug-ins.
- Story scripts live in `GrimDaysVN/dialogic/scripts/`; matching event resources live in `GrimDaysVN/resources/events/`.
- Scenes and scripts use Godot UIDs extensively. Move or rename resources through the Godot editor where possible so references remain valid.
- Much of the gameplay is data-driven through `.tres` resources. Prefer editing those through the Inspector unless a text edit is deliberate.
- `_debug`, `editor_only_debug`, files named `old`, and test scenes generally contain development material. Check actual scene/autoload references before classifying or removing a system; `_a_major_refactor` contains the active save/load implementation.
- Start with the [Code Documentation index](editor_only_debug/markdown_documentation/Code%20Documentation/README.md), [architecture guide](editor_only_debug/markdown_documentation/Project%20Documentation/Guidance/Architecture.md) and [documentation audit](editor_only_debug/markdown_documentation/Project%20Documentation/Historical%20Reference/Audits/Documentation%20Audit.md). Treat implementation and executed checks as the authority when documentation drifts.
- For player-driven placeholder testing, run `editor_only_debug/scenes/battle/courtyard_story_playtest.tscn`. Its two buttons start the Demorai or raider prelude and apply the level-3 milestone without automatic point allocation or test-only combat boosts.
- The main asset directories are large. Avoid broad asset reimports or format conversions unless they are intentional.

### Validation

For generated Action rank authoring, see the [rank resource guide](editor_only_debug/markdown_documentation/Code%20Documentation/Battle/scripts/Actions/Resources/ranks.md#generated-rank-authoring). A focused check is available at `editor_only_debug/scenes/battle/action_rank_progression_smoke_test.tscn` (`ACTION_RANK_PROGRESSION_SMOKE_TEST: PASS`).

Open each scene below and press **F6** in a debug build. Check both its PASS marker and the Debugger's errors; assertion-based tests are not release-build validation. These are project-specific scene runners, not suites under `res://tests/` for the generic MCP `test_run` tool. Through `godot-ai`, use `project_run(mode="custom", scene="res://...", autosave=false)` and stop the game between scenes.

| Scene under `editor_only_debug/scenes/` | Coverage | Expected output |
| --- | --- | --- |
| `battle/status_bombs_smoke_test.tscn` | All eight catalog status bombs: impact/status routing, single/all-foe targeting, DOT ticks, expiry, refresh, inventory consumption, retries, lethal hits, cleanup, VN metadata and existing item-menu/stun-flow regressions | `STATUS_BOMBS_SMOKE_TEST: PASS (8 bombs)` |
| `battle/battle_stat_model_smoke_test.tscn` | 50 suites: stats/progression, seeded combat, effects/actions, parties/inventory/equipment/skills, headless outcomes, production story/encounter/visual flow, courtyard handoffs, rewards, preparation and HUD | `BATTLE_STAT_MODEL_SMOKE_TEST: PASS` |
| `state_transition_smoke_test.tscn` | Queued state transitions, restoration, stale time-transition cancellation and the production Dialogic preparation call | `STATE_TRANSITION_SMOKE_TEST: PASS` |
| `gerano_story_handoff_smoke_test.tscn` | Intro ID registration without navigation scheduling; arrival timeline completion starts the room dialogue exactly once in place and retains the next event | `GERANO_STORY_HANDOFF_SMOKE_TEST: PASS`; exits automatically |
| `ordered_story_smoke_test.tscn` | All 47 timeline resources reachable; 46 real dialogue handoffs after the cinematic, three preparation screens, three production battles and post-battle scene loads; isolated accelerated party, no save writes | `ORDERED_STORY_SMOKE_TEST: PASS (46 dialogue handoffs, 3 preparations, 3 battles)` |
| `story_battle_handoffs_smoke_test.tscn` | Focused existing Harlok and three-nun suites: preparation, required-victory retry, victory/defeat branches, cover removal, summary and exactly-once continuation | `STORY_BATTLE_HANDOFFS_SMOKE_TEST: PASS`; inspect for failed assertions as well |
| `vn_upstream_fixes_smoke_test.tscn` | Eight default checks: save integrity, playtime, clock restoration, movement, audio buses, tooltip signals, navigation commands and repair-copy isolation | `VN_UPSTREAM_FIXES_SMOKE_TEST: PASS` |
| `documentation_behavior_smoke_test.tscn` | Time-name conversion, queue insertion behavior and loadable-audio state restoration | `DOCUMENTATION_BEHAVIOR_SMOKE_TEST: PASS` |
| `music_playback_smoke_test.tscn` | Music input forms, playback parameters, signals, invalid input rejection and previously failing resource/script loads | `MUSIC_PLAYBACK_SMOKE_TEST: PASS`; exits automatically |

**Generated-rank verification:** the latest [runtime-verification entry](editor_only_debug/markdown_documentation/Project%20Documentation/Historical%20Reference/Audits/Runtime%20Verification.md) records all 50 battle suites passing with zero runtime errors and 778 fixture warnings.

**Recorded verification:** the [runtime-verification log](editor_only_debug/markdown_documentation/Project%20Documentation/Historical%20Reference/Audits/Runtime%20Verification.md) records the 2026-09-26 battle runner passing all 49 suites. The fresh game log contains no runtime errors and 775 warnings, mostly repeated empty-tier notices. The record separately notes an MCP diagnostic-snippet compile error. Older VN/startup results retain their dates and engines; they are not fresh runs of this checkout.

The ordered-story regression was run with rendering enabled on Godot 4.7.2 for
Windows: all checks completed, with zero script errors, assertion failures or
save writes. It skips prose and accelerates combat, but uses real preparation,
actions, targets, result summaries and scene transitions. Run it with rendering
enabled (F6 or the normal Godot executable, not `--headless`); the scene loader
captures rendered transition screenshots. After the teardown fixes, the full
ordered-story and portrait/timeline runners exit 0 with no script errors,
retained-resource errors or ObjectDB leaks. This establishes integration and
clean shutdown, not normal-play balance acceptance.

The focused status-bomb runner passes all eight bombs and the existing consumable
menu/stun-flow suites with zero script/assertion errors and no save writes.
The headless bomb runner now exits 0 without detached-node path errors,
retained-resource errors or ObjectDB leaks.
Bomb mechanics are documented in the [item catalog](GrimDaysVN/resources/items/item_catalog.md#status-effect-bomb-mechanics).

The [teardown regression](editor_only_debug/markdown_documentation/Code%20Documentation/Debug%20and%20Tests/scripts/debug/teardown_smoke_test.md)
passes seven ownership/schema checks plus five existing stat/effect suites.
It checks array mutation, typed assignment identity, deep duplication, temporary
resource serialization, runtime speakers and audio cleanup. Runtime stats and the display helper are now
reference-managed; the rollback checkpoint helper is a child of its director.
The narrow vendored Dialogic fix removes unused subsystem `.new()` initializers
from typed accessors. Its accessor generator in
`addons/dialogic/Core/DialogicUtil.gd` emits the same ownership-safe declarations,
so editor regeneration preserves the fix.

The remaining script retention is fixed by typing effect follow-up arrays per
instance rather than retaining a self-typed script default. Inspector element
restrictions, serialized property names and existing resource identities remain
unchanged. The native shutdown crash was isolated to runtime-created Dialogic
speakers: their directory shared a dictionary with `ProjectSettings` and was
cached on `Engine`, retaining scripted Resources too late into shutdown.
`addons/dialogic/Core/DialogicResourceUtil.gd` now copies that dictionary and
caches it on the main loop. Runtime speakers remain reusable during play without
mutating project settings. Preserve these narrow vendor patches when updating
Dialogic. Ovani song players start polyphonic playback only when a song is
queued and release it when idle or leaving the tree, so idle players no longer
leak playback objects in unpaced headless runs.

Unused audio has been removed: every repository audio resource whose ID
nothing requests, plus its source audio. Remaining game audio is the `theme`
music, the start-scene crow/hammer effects and the two battle defeat screams;
Dialogic's typing sounds are kept because its textbox loads that folder
dynamically. The ambient, effect and Ovani repository folders are intentionally
empty but retained for future content.

Run `.\tools\test-teardown.ps1` to check the ownership runner headlessly and the
portrait/full ordered-story runners with rendering. It requires each PASS marker,
exit code 0, and no script errors, retained-resource errors or ObjectDB leaks.
Use `-EnginePath` if Godot is not at the default Downloads location. In the
focused bomb test, leaked instances have fallen from 1,259 to zero and retained
resources from 124 to zero. Diagnostics remain enabled.

The documentation audit did not create an export or rerun VN checks. The optional ninth VN check, enabled by `VN_TEST_SAVE_IO=1`, exercises real queued save/load operations and requires an isolated `XDG_DATA_HOME` beginning `/tmp/vn-save-integration-`. It was not run. Full unskipped story playback, encounter balance, all save-slot scenarios and a Windows export are not established by these checks. Courtyard smoke fixtures accelerate combat and intercept the aftermath, so PASS establishes integration rather than normal-play pacing. There is no checked-in project CI workflow.

## Bundled add-ons

Enabled in `project.godot`:

- Todo Manager 2.3.1
- Dialogic 2.0 Alpha 20 WIP (manifest: `2.0-Alpha-20 WIP (Godot 4.4+)`)
- Godot AI 3.2.5
- Input Helper 4.4.0
- Phantom Camera 0.11
- Profily 1.0.1
- GIF Replay Recorder 1.1.2
- SoundManager 2.6.2

Other add-on directories may be present but disabled. Consult each bundled add-on's own README, plug-in manifest, and license before updating or redistributing it.

## Status and caveats

This is explicitly a prototype. The codebase contains overlapping generations of architecture, incomplete TODOs, debug-only utilities, placeholder/generated media, and resources that may only be exercised by isolated scenes. The main menu's Extras action is currently a stub. Battle work includes production story handoffs, preparation, rewards and recovery as well as deterministic resolution and headless execution, but encounter balance and full-story acceptance remain open. The courtyard threat choice's advertised Strength check is still unimplemented. Expect to use Godot's debugger and run focused scenes when changing a subsystem.

The documentation-behavior runner intentionally records two current limitations: inserting a task before the third queued task places it before the second, and restoring loadable 2D/3D audio state restores volume and pitch but not position. A passing characterization check does not mean those behaviors are fixed. Use the matching engine/runtime and let imports settle before investigating missing-resource messages.

## License

The root `LICENSE` is the MIT License, copyright © 2020–present Zae Chao (zaevi). Third-party add-ons carry separate license files in their respective directories. Audio, fonts, artwork, and other media may have separate attribution or redistribution terms; verify their source licenses before publishing a build or redistributing repository assets.
