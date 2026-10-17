# Production battle integration

This module is the new production boundary, not a replacement implementation of
the debug controller. `debug_battle.tscn` and `debug_battle_controller.gd` remain
debug tools. `GameEventBattle` now enters the visual production encounter through
the stable `battle` scene key; production never launches a headless runner.

For historical work ordering and decision gates, see the
[archived Battle MVP implementation plan](../../../editor_only_debug/markdown_documentation/Project%20Documentation/Historical%20Reference/Plans/Implementation%20Plan%20-%209_25_2026.md).
Historical stage labels below are not an instruction to repeat completed systems.
The project-owned skill system now replaces Yggdrasil. Celine's current authored
collection is enabled; completing its content and the dorm-to-Nuns MVP remain
planned. The consolidated ledger distinguishes smoke checks from visual acceptance.

Current components:

- `BattleCoordinator`: encounter lifecycle, session tokens, result finalization.
- `BattleEncounterRoster`: references to permanent allies; ownership of foes;
  battle-effect cleanup and restoration of base affiliation/control.
- `BattleTurnOrder`: stable practical-speed ordering and advancement without global signals. `STATS.Swiftness` is Finesse-derived raw capacity (including modifiers); `BattleUnit.speed` applies Encumberance for turn ordering. The Swiftness resource/key migration retains numeric enum value 360 and existing resource UIDs/curves; no legacy save alias is maintained.
- `BattleRandomStreams`: shared deterministic participant seeding. The old debug
  path is a compatibility wrapper retaining its UID.
- `BattleVisualStage`: binds existing roster units to authored displays, routes
  target selection locally and releases visual bindings before roster cleanup.
  Its reusable scene is `scenes/battle/production_visual_stage.tscn`; it contains
  scenery, cameras and display holders, not participant selection or combat logic.
- `BattleEncounterFlow`: local player/AI turn states, immutable action requests,
  cancellation and result progression. It composes the existing action resolver.
- `BattleActionEffects`: per-request ranked effect grants, recipient expansion
  and routing without firing unrelated recipients' passive trigger buckets.
- `BattleResourceEventCapture`: scoped observation of individual resource-effect
  operations, including nested chains, reactive sources and lifecycle hooks.
- `BattleEncounterEffects`: encounter-local round expiry and defeat/kill hooks.
- `BattleActionPresentation`: bounded approach/return pacing and camera reset.
- `BattleCombatPresentation`: ordered, time-bounded attack and outcome playback;
  damage/healing/miss/critical/defeat/revival feedback observes resolved events.
- `BattleEffectPresentation`: encounter-local dispatch of authored animation,
  sound and particle requests; cosmetic playback does not gate effect completion.
- `BattleActionMenu`: owned-action selection, pass and target cancellation.
- `BattleStorySession`: scene replacement, correlated completion and cancellation.
  It lives under SceneManager only for an encounter; no VN scene is suspended.
- `BattleRetryCheckpoint`: in-memory rollback of pre-battle stats, modifiers,
  effects, source-owned overrides, action ranks and cooldowns on the same units.

`scenes/battle/production_encounter.tscn` composes these components. Instantiate
it, add it to the tree, then call `begin_session(party, foes, encounter_id, seed,
return_context, rewards, require_victory)`. It never opens a participant picker or starts a
headless runner. The story's `scenes/root/battle.tscn` is an instance of this scene.

The production encounter scene owns its coordinator. Inject the
existing `BattlePartyManager` into `begin_session`; do not instantiate another
party manager. Only foes, encounter identity, seed, rewards and return context
come from encounter authoring. Permanent allies remain children of their runtime
party manager throughout deployment and cleanup. Visuals must bind these same
instances, not recreate them from templates.

After deployment, call `BattleVisualStage.bind_encounter(coordinator)`. The stage
owns only the displays it creates. The action layer calls `select_targets` with
the session token, actor and action, then consumes the stage's token-correlated
`target_added` / `target_removed` signals. `clear_target_selection` closes input.
The stage does not consume global debug navigation/selection or cosmetic-request
broadcasts. Authored animation, sound and particles use its injected
`BattleEffectPresentation`; legacy debug displays keep their signal-bus path.
Navigation completion is available through each display's `movement_finished`
signal. The production flow uses its own bounded presentation component, so
missing animation completion cannot prevent turn advancement.

Retain `session_id` when beginning asynchronous phase/presentation work. Check
`is_current_session` before applying late work and pass that token to `finish`
and `cleanup`. A result is emitted once. Saving remains blocked until cleanup;
the centralized save gate checks production coordinators, story handoffs and
the legacy debug controller. Queued save/checkpoint tasks recheck before any
slot writes and after gathering persistent data. Loads cancel story sessions
before resetting or replacing permanent units. Mid-battle saves are unsupported.

Integration follow-up:

1. Verify the automatic combat sequence with authored visual assets and the
   implemented loadout/result/reward UI. Basic Attack now selects its wind-up
   through `attack_animation`; damage remains a domain effect, not an animation callback.
2. Keep template-based selection, automated input and headless balance tools in
   the debug area; never route production through the debug selection scene.

The modular smoke runner includes `production_encounter_smoke_suite.gd` for
two-encounter grant survival, teardown, source overrides and stale-session guards.
`production_visual_smoke_suite.gd` instantiates the actual visual stage and checks
runtime identity, HUD/tooltip updates, local targeting, rebinding and cleanup.
`production_flow_smoke_suite.gd` exercises the composed visual scene through
multi-target victory, multi-round AI defeat, cancellation, round-effect defeat
without a killer, roster-scoped targeting/expiry, and no-action turn yielding.
`production_story_smoke_suite.gd` covers timeline-ending entry, scene replacement,
victory/defeat branches, repeated defeat/draw retries, fractional pool restoration,
expired baseline effects, persistent-modifier rollback, cooldowns, stale retry
tokens, save rejection, cancellation, caller-neutral entry and a player-driven
Basic Attack victory after retries.

Story battle authoring:

- `foes` contains opponent templates only; allies come from the runtime party.
- `finished_event` is the victory event (the existing serialized name is retained).
- With `require_victory = false`, `defeated_event` is required and runs on defeat.
- With `require_victory = true`, defeat cannot advance the story. A Try again
  button resets the attempt, preserving the original seed and party instances.
- DRAW offers retry in either mode; it never counts as victory. ERROR and
  cancellation do not run finishing actions or story branches.

An explicit event request on a timeline's final instruction waits for
`Dialogic.timeline_ended`. A reaction to the ending timeline can also request the
battle. Entry is deferred out of signal callbacks, validates/deploys the encounter,
then frees the outgoing VN scene and makes battle the current scene. It does not
pause or resume that ended timeline. GameManager's ending handler captures its
original event and ignores stale callbacks when a replacement was requested.

After an accepted result, combat cleanup precedes exactly-once finishing actions
and the selected follow-up event, which owns the next scene/timeline transition.
The finished battle remains the outgoing scene until that transition replaces it.
Missing required branch resources are rejected before replacing the VN scene.
Accepted victory settles rewards and recovery before the result summary; Continue
releases caller progression. Failed attempts never emit `encounter_completed` or
run progression actions. See the settlement/summary contracts below.

Future non-story systems can instantiate the same scene, call `begin_session`,
and consume `encounter_completed` without GameEventBattle/Dialogic. The raw
`battle_finished` signal and `begin_encounter` API describe individual attempts;
progression consumers should use the session-level completion signal. The caller
must clean up (`cancel_session`) and replace/free the finished scene. Retry UI
and reset logic are part of this shared scene, not the story adapter.

Retry checkpoints are runtime-only, not mid-battle saves. All effect removal
handlers run before restoring the modifier ledger, and baseline effects are
reconstructed without replaying their operations. Permanent units, equipment and
project-owned skill components retain identity. Unit inventories are restored to their
pre-attempt contents on retry (including consumed stacks); their nodes retain
identity. Definitions are held by the runtime checkpoint, not resolved from disk.
The shared stash is not available during combat and is not part of this rollback.
Accepted outcomes retain supply consumption. Reward grants remain outside attempt
resolution and must use a separate accepted-result transaction policy.
The persistent party is still hosted under the legacy autoload; production only
reads its `party_manager`, never calls its combat orchestration. The title-screen
Extras battle selector remains a debug tool, not the story entry contract.

Simultaneous elimination resolves to DRAW. Production rounds invoke effects on
their participants directly, without broadcasting `battle_round_end`. Runtime
units receive an injected participant source so shared action/chain helpers and
AI target checks never query debug holders during a production encounter.

## Stage 1 state-correctness contract

Victory/defeat uses the original deployed ally and foe collections, not effective
team membership. Temporary allegiance/control changes affect targeting and input
only. Original foes all inactive means victory; original allies all inactive
means defeat; both inactive means draw. No environmental damage system is planned.
Direct attacks and DOT retain the originating combatant, including after that
combatant is defeated. Defeated sources remain in the roster until cleanup;
attribution persists, but only active sources execute KILL effects. Victim-scaled
damage does not change the attacker identity.

Encumberance evaluates as a capped scalar for base changes, dependencies and
modifier add/remove paths. Production turn ordering uses the unit's effective
speed including Encumberance. Combat pool changes clamp after rounding; save
restoration preserves exact fractional current values. Party restoration builds
action ownership and project skill maximum-stat grants before applying saved pools
and cooldowns, including actions owned exclusively through a tree.

Every effect trigger supplies its current cancellation guard to nested chains.
Chains check it between children/recipients and while awaiting child completion;
a cancelled encounter cannot continue into a later child operation. The
`stat_state_smoke_suite.gd` and `encounter_state_smoke_suite.gd` regressions cover
these contracts. Equipment/inventory persistence and production presentation
integration are implemented in the corresponding sections below.

Local addon compatibility fix: PhantomCamera2D now unregisters from the same
PhantomCameraManager autoload used on entry; the old unused-singleton guard left
freed cameras registered and broke subsequent encounter scenes.

## Action effect contract

The request preserves original selection history. `BattleActionContext` owns the
live targets: substitution updates them directly, and all subsequent operations
are created on their actual recipients. Existing attached effects are not moved.

1. Pay once: normal rank cost/cooldown, or one inventory item with no stat cost/cooldown.
2. Resolve individual hostile TARGETED, including substitution, before ATTACKING.
   The replacement skips TARGETED; group AOE and DOT do not create individual selections.
3. For each damaging operation: accuracy, defender BEFORE_DAMAGE, attacker
   AFTER_HITTING, then calculate magnitude and apply mitigation/Health change.
4. Defender DAMAGED sees updated Health, including zero. If still inactive, resolve
   DEFEAT; only continued inactivity permits binding expiry and KILL.
5. PROCESS_OVER uses the live target list. Costs and action completion occur once.

Any individually targeted hostile action qualifies, including non-damaging debuffs.
A genuinely new individual/random selection may respond once during the action.
Retaliatory effects retain their damage source without exchanging action roles;
the action owner does not receive a defender DAMAGED window merely for retaliation.

Authored DAMAGED=200 payloads remain operation definitions; they are not the passive
post-damage response bucket. BEFORE_DAMAGE=900 leaves existing serialized values
unchanged. Per-life markers prevent later production/legacy defeat handoffs replaying
responses already completed inside the action. Retry restores those markers.

Each definition/recipient is granted once per request, with separate per-hit scopes
for authored AFTER_HITTING operations. Group and self effects do not multiply with
selected-target count. New effects attach to their actual recipients, including
substituted units. Rank source policy comes from the unit/inventory/tree grant.
EQUIP remains reserved for equipment/passives and is rejected before action payment.

TARGET_SUBSTITUTED records the replacement as the event target; original selection
is metadata for history/presentation only. A presentation cue is available; full
interposition choreography and demo-route visual acceptance are not yet verified.

Resource events capture each scaled/flat/percentage operation across the encounter,
including actor healing, area damage and reactive effects. Zero-net damage/healing
pairs are not collapsed. Metadata identifies the effect, instance, grant source,
stat, before/after values, raw amount, mitigation, critical flag and trigger.
For action operations, `stage_trigger` identifies the enclosing dispatch and
`action_actor` identifies the initiator; `event.actor` is the original effect sender.
Defeat/revival transitions are recorded after their Health operation while the
final defeated list excludes units revived before action end.
Cancellation is checked between operations as well as between stages. The new
`action_trigger_routing_smoke_suite.gd` covers these rules, rank selection, random
recipient expansion, revival, and a visual player-driven kill/defeat sequence.

## Authored presentation routing (Stage 2, first batch)

Each stage binding installs a `presentation_request(kind, payload)` callback on
its existing runtime units. A dedicated dispatcher borrows the stage's displays;
it never consults the debug controller or creates replacement combatants.
Animation suffixes are resolved at playback from display placement, not unit
parenting or current team. Missing assets/displays are skipped, and cosmetic
effects complete synchronously even if playback loops or never signals completion.

Stage cleanup invalidates the dispatcher before freeing displays and restores
prior callbacks only when still owned by that binding. Attempt tokens reject
late requests; explicit invalidation also covers rebinding within the same attempt.
External code retaining a callback must check `is_valid()` before invoking it,
because the dispatcher may already have been released. Bound production units
never fall back to debug routing when their callback becomes invalid.

This dispatcher starts authored cosmetics immediately; it is not an ordered
combat-event player. Resource-operation events are now available (see below);
bounded action/hit/death pacing is implemented by the separate automatic playback
component below. Sounds/particles are owned by displays; legacy
completion notifications may still be emitted but production progression does
not wait on them. `production_visual_smoke_suite.gd` tests real production
dispatch with temporary looping animations, silent audio and particle expiry.

## Resource-operation events (Stage 2, second batch)

The operation-level prerequisite above is now implemented for scaled and
flat/percentage resource effects. The resolver observes participant-local signals
only during an action stage and disconnects before publishing the resulting
events. Round/defeat/kill processing similarly returns ordered events; the
production flow appends them to the current result only while its attempt remains
current. Round dispatch and its defeat hooks share one capture to avoid duplicates.
Lifecycle events carry an attempt-correlated request ID and no current action.
DOT keeps its original sender even when that sender is defeated.

`RESOURCE_CHANGED` represents non-Health pools; `REVIVED` records a zero-to-positive
Health transition. Critical is followed by its resource event and then any defeat
transition. Amounts are the actual clamped pool deltas, including zero when an
operation is fully mitigated or restores a full pool. Effect completion and
combat mutation never wait for these observers or cosmetic completion.

This is not an event-sourced save/replay system: cost payment retains its existing
`COST_PAID` stage, and stat-ledger changes, team/control changes and authored
cosmetics are not operation events yet. Max-Health modifiers must not masquerade
as damage. Cancellation closes observers; discarded attempts are not published
as accepted results. Automatic visual sequencing is implemented below.

## Automatic production playback

The flow now approaches, plays the action's optional `attack_animation`, resolves
combat and lifecycle hooks, presents their ordered events, returns the actor and
only then finalizes/advances. Round effects also receive feedback before outcomes
are finalized. Combat mutation never depends on animation callbacks.

`BattleCombatPresentation` accepts damage, healing, miss, critical, defeat and
revival cues. It caps each cue and the overall sequence; remaining events settle
immediately if the total budget is exhausted. Missing clips/displays skip safely,
looping clips cannot deadlock, death retains its final pose and revival restores
transforms/HUD opacity. Attempt continuation plus binding identity rejects stale
playback, including same-attempt rebinds. Cancellation releases the active clip.

Production floating text and critical feedback no longer subscribe to duplicate
global result notifications. Legacy debug displays retain their original route.
HUD resources still observe live stat changes; this is not a delayed state replay.
Authored cosmetic operations dispatch at resolution time and may precede automatic
feedback; their integration into the event sequence is a future presentation refinement.

## Equipment grant ownership

Each Equipable has an opaque `item_instance_id` and an `equipment:<id>` grant
source. Equipment slots preserve that identity in their state. The wearer is the
effect sender/scaler, while the item source owns reversible grants and equipped
weight. Two copies of one template do not collide. Unequip removes only that
source; it must not remove unrelated effects sent by the same combatant.

Instant EQUIP operations execute once when equipping; other instant effects stay
deferred until their trigger. Project skill effects likewise use the unit as combat
sender while keeping the existing stable skill-tree source IDs. Inventory transfer
and full loadout save integration are implemented in the sections below. Weight
means equipped weight only; carried inventory contents add no weight or grants.

## Equipped-loadout persistence

`BattleEquipmentLoadout` stages starting equipment during production unit creation
and serializes occupied slots with template identity, resource path and instance
ID. Starting collections use authored item order and each item's first available
compatible slot; conflicts fail unit preflight instead of silently displacing.
Saved record order preserves weapon-action override precedence.

Party loading creates units without starting equipment for saved characters.
Saved loadouts are authoritative, including an intentionally empty loadout. New
permanent characters absent from a save receive authored defaults. Loadout records
are validated before replacement; invalid/duplicate IDs or slots return warnings
without partially replacing the current equipment. Definitions resolve through
the equipment registry, starting collection or matching authored resource path.

Reconstruction revokes old equipment grants synchronously, then rebuilds equipment,
project skill grants, cooldowns and exact current pools in that order. Equipment-derived
modifiers are not independently serialized. Restored items never replay instant
OnEquip operations. Legacy slot loading follows the same no-replay rule.
### Shared stash and individual combat inventories

The persistent party owns a shared `stash`; every constructed BattleUnit owns an
`inventory`. Only the latter is available to that unit in combat: there is no
automatic stash/other-unit fallback. Prototype capacities are 64 ordinary stash
slots and 9 per-unit slots, with currency in a separate reserved slot zero.
Neither stored items nor currency contribute to Weight; directly equipped items
remain its only item-based source.

Preparation code calls `BattlePartyManager.transfer_item(from_id, to_id, slot,
amount)`, using an empty ID for the stash. Unknown owners, self-transfers, invalid
quantities and insufficient capacity fail without consuming anything. Transfers
are disabled while an encounter reserves the party, including its retry prompt.
Low-level `Inventory` operations are for grants, consumption and restoration;
they do not enforce party/encounter ownership themselves.

Party saves include stash state and each unit's independent inventory. Records
retain capacity, slot order, currency, template ID/path and counts. Restoration
resolves ItemTemplates and validates the whole inventory before replacing it;
unknown definitions or malformed stacks produce warnings, not partial replacement.
Re-entering the scene tree does not clear items. New-game reset explicitly does.
Required-victory retries restore consumed supplies; accepted outcomes do not.
`equip_inventory_item(unit_id, inventory_slot, equipment_slot)` and
`unequip_inventory_item(unit_id, equipment_slot)` are production preparation entry
points. Equip uses that unit's inventory and returns displaced gear to the vacated
slot; full inventories permit one-for-one swaps. Unequip fails unchanged if storage
is full. Both APIs share the encounter lock and settle ownership before OnEquip.

Equipment is unstackable (`stack_size = 1`) and retains its individual instance ID
across inventory saves, transfers, swaps and re-equipping. Duplicate stored IDs are
rejected. Low-level template equip APIs remain for authored grants/debugging, not
inventory transactions.

### Combat consumables

`ConsumableTemplate.battle_actions` references action definitions: normally one
unique resource, with separate definitions for deliberate alternate targeting modes.
`BattleItemAction.available(unit)` creates transient choices backed by exact personal
inventory stacks. Item name/icon/quantity remain inventory UI data; targeting,
restrictions, animation and rank-one effects come from the action.

Selection/Back spends nothing. Committing consumes one item regardless of recipient
count, emits `ITEM_USED`, and uses normal action resolution, including accuracy and
defensive reactions for damage. Authored stat costs and cooldowns are ignored for
inventory use. No learned ownership or separate action save record is created.
Stale/replaced/foreign/depleted stacks and repeat submissions are rejected.
Restrictions are checked at selection and commit. Effects retain authored triggers
and targets; the old OnUse normalization and item-only dispatcher are removed.

Ally categories exclude the actor; author a separate Self choice when needed.
Defeated-unit targeting is unsupported by current target rules. No supply shop,
AI item strategy or automatically granted production supplies are implied.

### Accepted-result recovery and foe lifetime

The accepted session result (victory or permitted defeat) invokes `BattlePartyRecovery`
exactly once, before caller continuation. Only originally deployed party members
are processed: defeated members recover to 1 Health, surviving Health is retained,
Mana is retained, and Energy/Lucidity refill to their effective maxima when present.
Stat bounds still apply, including a zero effective Health maximum. Undeployed
reserves and foes are not healed. Required-victory failures and draws do not use
this recovery; they retain the existing checkpoint/retry policy. Errors and
cancellation do not trigger recovery.

`BattleResult.ally_snapshots` remains terminal combat history. A separate
`recovered_party_snapshots` records returned party pools, and `party_recovered`
guards duplicate/re-entrant completion. This is session acceptance behavior;
raw `begin_encounter` debug attempts do not settle party progression automatically.

Foe snapshots include value-only `loot` candidates from lootable inventory
stacks/currency and equipped gear, plus authored `experience_reward`. Records retain
template ID/path, count and equipment instance ID, not live Node/Resource references.
This reward amount is separate from the foe's own Experience stat.

### Victory settlement and shared-inventory overflow

Only accepted victory awards rewards. Every originally deployed party member,
including defeated members, receives the **full** encounter experience plus the
defeated original foes' experience rewards. Undeployed reserves do not receive it.
Accepted defeat restores the party but grants no loot or experience. Failed
required-victory attempts, draws, errors and cancellation do not settle rewards.

The optional encounter dictionary supports `experience` and `money` (non-negative
integers) and `items` (array of `{template_id, resource_path, count, instance_id?}`
records). Unknown fields/definitions or malformed quantities block settlement rather
than silently dropping rewards. Instance ID is optional for newly granted equipment;
receipts retain the generated IDs. Foe loot preserves existing equipment identity.
Experience totals are limited to 2147483647; preflight validates foe reward bounds.

`BattleRewardSettlement` stages the complete stash result before any persistent
mutation. Success grants items/currency to the shared stash and XP to the original
party, records a value-only `reward_receipt`, then applies recovery. Re-entrant and
duplicate callbacks cannot repeat payment or completion. Only after success does
coordinator cleanup free foe nodes; receipts and terminal snapshots survive them.

If rewards do not fit, shared capacity **does not grow**. A production overflow
panel shows the stash and incoming loot. The player can explicitly discard one or
a whole stored stack, or leave one/a whole incoming stack behind, then collect.
Stored discards are immediate/permanent player decisions; declined loot is tracked
separately from immutable foe history. No partial XP/currency/items are awarded
while choices are pending. The encounter retains foes, its party lease and save
guard; ordinary combat preparation transfers remain locked. Old buttons/attempts
cannot discard replacement stacks or collect after cancellation. Invalid reward
definitions show an authoring error rather than an unsafe inventory panel.

### Result summary and Continue

Every accepted victory/permitted defeat now shows `BattleResultSummary` after
settlement and recovery. It displays the outcome, turn/round counts, XP per deployed
member, actual collected items, declined loot quantity and recovered party pools.
It reads value snapshots/receipts only; foes have already been freed.

`encounter_completed` is emitted only after explicit Continue, never when opening
the summary. Turn input stays stopped. The scene holds a temporary party reservation
and save guard during acknowledgement, releasing both on Continue, cancellation or
teardown. Repeated/stale clicks and terminal notifications cannot grant rewards,
recover pools or continue the story twice. Cancelling after settlement suppresses
caller continuation but does not reverse already-committed rewards/recovery.
Errors do not use this accepted-result screen; failed required-victory attempts and
draws retain the existing retry prompt. Raw debug `begin_encounter` remains separate.

### Party preparation access

Preparation is **not** an always-available menu. Navigation's inventory button
calls `UIDirector.show_party_preparation()`. Story authors explicitly insert a
Dialogic Call event in a running Scenario/ScenarioSequence/ScenarioLewd/ScenarioSleep
timeline:

```text
do UIDirector.show_story_party_preparation()
```

Neither entry permits combat, loading, replay, an existing modal pause, an active
encounter/reward summary or a scene transition. Navigation entry also rejects an
active timeline. No global shortcut or generic signal command is added.

`BattlePreparationSession` owns a temporary party reservation and tree pause;
GameManager stays in its current mode, so closing never re-enters Navigation or
replaces its scene. Saves are blocked until close, and load/reset cancels the visit.
The story adapter takes continuation of the exact Dialogic Call event and advances
once, deferred, only when caller/timeline/index still match. It deliberately avoids
an addon `handle_event` coroutine left awaiting resume after cancellation. Replacing
a timeline releases preparation's pause before the replacement's first event.

The modular panel edits one-to-four active party members, transfers one/all items
between stash and the selected permanent unit, equips owned items, and returns
unequipped gear to personal storage. Existing atomic capacity/identity rules remain
authoritative; the UI does not create, grow or merge inventories. Equipment alone
contributes Weight. Changes commit immediately; Done/Back is not undo.

Skill tabs render project-owned tier/row pages over the unit's investment ledger.
A single draft spans trees; Apply atomically purchases ranks through the lease- and
revision-checked party service. Minus/Clear affect pending ranks only. Closing or
switching units discards uncommitted choices. Each rank costs one shared skill point;
there is no ordinary refund UI. Node details preview payloads and explain gates.
Manual readability/controller-navigation QA still needs content-level acceptance.

Next: courtyard balance/full-story manual acceptance, followed by neutral party-service
and legacy cleanup. The debug battle controller and scene remain unchanged.

### Courtyard story slice

The orphanage courtyard's existing dialogue choice selects one of two authored
handoffs. `2_0035_fight_harlok_alone` deploys Harlok; `2_0032_fight_harlok_and_goons`
deploys Harlok, Goon A and Goon B. Both are registered, explicitly called
`GameEventBattle` resources. Neither defines allies: Celine comes from the current
runtime party. Their seeds are 2035 and 2032 respectively.

Each handoff timeline explicitly opens preparation, requests its encounter and
ends. Both require victory: failed attempts retry the original checkpoint/seed,
without rewards or story advancement. An accepted victory shows the usual reward
summary; Continue starts the existing `2_0040_fight_aftermath` event exactly once.
No encounter-level reward amount or combat stat has been invented for this slice.
Existing foe rewards and all settlement rules still apply.

Goon templates now reference their already-authored individual Spine scenes and
VN portraits instead of Harlok's artwork. Their original stats/levels are retained.
The threat choice's advertised Strength check remains NYI; this change does not
silently introduce a dialogue-stat policy. The basement/nuns sequence is untouched.

`courtyard_story_smoke_suite` runs both real handoff timelines through preparation,
registry lookup, scene replacement, retry, player action/target input, summary and
exactly-once continuation. Its combat fixtures accelerate kills and intercept the
aftermath; they prove integration, not encounter balance or the full cinematic.

For direct player-driven QA, run
`res://editor_only_debug/scenes/battle/courtyard_story_playtest.tscn` with F6.
Its two buttons apply the post-office level milestone and start the same authored
handoffs without test-only stat modifiers or automatic point allocation.
Production formation columns are centered with 360px spacing, and status panels
draw above sprites; this avoids overlapping/occluded names and Health in the
three-foe encounter. The legacy debug formation is not changed.

### Post-office level milestone

Celine intentionally starts at level 0 in her template. At the existing leveling
screen placeholder near the end of `2_0010_five_years_later`, after Ursula's
scolding and before returning to Navigation, the timeline now calls:

```text
do DialogicRelay.ensure_party_unit_level("CelineTeen", 3)
do UIDirector.show_story_party_preparation()
```

The party service raises **earned XP to a minimum threshold**, using the same
authored curve inverse as unit creation. It never lowers later XP or adds the
threshold repeatedly. Current data yields 1,800 XP, level 3 and 16 combat / 6
non-combat points available for the player; the existing tier also reports 21 skill
points, spent at one point per project skill rank. Automatic tier growth
still follows the existing resource. No discretionary points are auto-allocated.

Existing point-ledger persistence/high-water/revision rules prevent duplicate
grants or spending after restore/repeated calls. Encounter ownership blocks the
milestone, replay cannot grant it, and missing units/unreachable levels fail without
changing XP. Level modifiers are not used to counterfeit earned XP. This milestone
does not heal pools, change enemy templates or force a build on the player.

The F6 courtyard launcher skips office dialogue but applies the same milestone
before opening preparation. Both courtyard variants assume a prepared level-3
Celine; level-0 playtesting is not the intended balance baseline.

### Calculated-stat curve contract

Attribute-derived curves author **gains per influencing point**, not final totals:
`base = sum(curve.sample(n), n = 1..floor(influence)) + starting_amount`.
Fractional influence adds the corresponding fraction of the next point's gain;
zero/negative influence contributes zero. Outside the authored curve domain,
endpoint gains continue. The upper constant tail is multiplied rather than looped.

Every recalculation rebuilds that base from the definition, then the existing
modifier ledger determines the effective maximum/value. Starting amount is added
once; effects never compound because a previous runtime total is not the input.
Resource pools retain the existing fill-ratio policy when their maximum changes.
Weight Limit accumulates the same gains using its existing rounded average of
Strength, Vitality and Endurance. Swiftness remains distinct from encumbered speed.

**Level is explicitly a direct total-XP lookup**, including its starting offset.
Creation and story-milestone XP inversion share that calculation. Scaling-stat
threshold curves are also unchanged; they are not per-point gain curves.

No authored curve data was rewritten. For Celine, the first Vitality point grants
150 Health and points 2–49 each grant 30: 5 Vitality yields 270 plus starting_amount,
6 yields 300. The earlier apparent 30-Health plateau was a calculation bug, not an
encounter-balance decision. Courtyard balance still requires a prepared playthrough.

### Opening defensive investment

The confirmed courtyard target is about six rounds for solo Harlok (normal) and
nine for Harlok with goons (mid-boss), averaging imperfect prepared play. Existing
progression remains authoritative over the brainstorming documents/spreadsheet.

The four courtyard templates now cap attribute-derived Physical/Magical Resistance
and Evasion at 20%, Lucky Evasion at 5%, with zero minimums. At level 3 the first
three need 50 Endurance/Willpower/Finesse respectively; Lucky Evasion needs 40 Luck.
These provisional low baselines reserve higher defense for direct equipment,
passive and active-effect grants applied after base evaluation. Attribute bonuses
cannot bypass the base caps; direct defensive modifiers can. Celine/Harlok's visible
rough clothing grants no armor. Progression, Critical Strike and Luck retries are
unchanged. Full Finesse investment yields 12% Evasion; full Endurance yields 11.2%
resistance. An 8/8 split gives 8.8% / 8%, retaining 55 Physical Damage versus 135
for Strength investment.

See `resources/stats/scaling/README.md` for curve domains and the documentation's
`Battle/Courtyard Balance.md` for measurements. Passing tests establishes the
investment trade-off, not completed pacing, danger, or player-facing acceptance.
