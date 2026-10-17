# Project-owned skill progression

The project-owned system is the sole skill progression path. Templates use
`skill_collection`; `BattleUnitSkills` owns per-unit investment and live grants.
Celine uses the authored replacement collection; Harlok and both goons use their
Street Bullies collections and default investments. Yggdrasil code, autoloads, bridge and
legacy view resources have been retired. No legacy allocation conversion occurs.

Historical decisions and implementation evidence are recorded in the
[archived consolidated plan](../../../editor_only_debug/markdown_documentation/Project%20Documentation/Historical%20Reference/Plans/Implementation%20Plan%20-%209_25_2026.md).
Battle Workshop remains deferred and is not a prerequisite.

- A collection requires at least one tree. Empty trees support units with no
  purchasable nodes. Empty tiers are omitted at runtime with per-unit initialization
  warnings; authored tiers/columns remain unchanged. IDs are stable; node IDs are unique across the collection.
- Each tree owns explicit tier columns and node rows. Tier/node stat bounds are
  inclusive and combined with AND. Missing/nonfinite required stats fail closed.
- Prerequisites specify minimum purchased ranks; every prerequisite must also be
  available. A same-row predecessor additionally requires at least its first rank.
  Predecessors must be earlier same-tree nodes of the same action/passive kind.
- Definition validation rejects ambiguous cells/IDs, invalid ranges/ranks, absent
  dependencies and cycles before the ledger traverses availability.
- One `BattleSkillInvestment` belongs to one unit, never one tree. All ranks cost
  one point. Purchase takes a complete draft, authoritative earned-point total,
  current stat values and expected revision. Any error rejects the whole draft.
- Capture/restore contains only versioned purchased ranks. JSON whole floats are
  accepted; corrupt/overspent/unrecognized data rejects atomically. Availability
  is not saved and does not erase valid investment. The unit integration clears
  all invalid persisted investment and its derived grants, exposing earned points
  unspent without increasing the allowance. Restoring invalidates stale revisions.
- `reset_all` is a low-level primitive, not UI authorization. The story reset
  service validates the currently executing Dialogic Call. There is no
  individual refund operation. Configuration is for new ledger construction, not
  a production refund API. Treat shared definitions as immutable after configure.

`BattleSkillNode` is an abstract payload strategy with shared identity, grid,
gates and prerequisite fields. Create `BattleSkillActionNode` for ranked
ActionTemplates or `BattleSkillPassiveNode` for passive stat/effect payloads.
There is no KIND selector: each subclass exports only its own payload.
Validation, chain compatibility, plan generation, UI labels and action-source
ownership dispatch through the node strategy. The resolver retains shared chain
traversal; the reconciler retains source ownership and lifecycle bookkeeping.
Changing a node's strategy requires replacing its Resource while preserving its
stable ID when appropriate; mixed action/passive predecessor chains are invalid.
The authored Control resource retains its existing UID, ID and five ranked values.

Nodes bind ranked ActionTemplates or passive stat/effect payloads. Layout-only
definitions can still be edited/investment-tested, but the battle compiler requires
valid payloads for every node. Passive effects must be SELF / WHILE_SOURCE_ACTIVE.

`BattleSkillChainResolver.resolve()` derives the highest available tip per connected
same-row chain and follows predecessors only until a replacement boundary. Costs
and effects use retained purchased ranks, in order. Highest tier owns targeting/
cooldown; lowest retained tier owns initial animation. Cross-row prerequisites do
not merge payloads. Disconnected chains remain independent, even on the same row.
The existing resolver still dispatches by trigger stage; component ordering is
preserved within each stage, not a replacement of the combat trigger scheduler.

Runtime actions have stable, namespaced chain IDs across fallback. Only their tip's
current rank is executable; generated containers do not modify authored Resources.
Leaf effect definitions are shared immutable data, just as in normal action routing.
The action resolver now rolls each immediate damaging effect independently,
including chained children. Effect-level `always_hits` bypasses accuracy/evasion;
the legacy action-level flag remains a compatibility override. Immediate incoming
damage and after-hit passives now dispatch per operation under recursion guards.
Authored after-hit action procs also run once per originating hit and use its actual
recipient; proc damage cannot recursively schedule the same authored proc list.
Round/defeat/kill damage now uses fresh accuracy/reaction contexts, preserving
defeated DOT sources without replaying old action procs. Hostile targeting reactions
run once per source/recipient before accuracy, for genuine individual selections. Group expansion, DOT and retaliatory damage
do not synthesize TARGETED responses. Misses still trigger targeting; friendly
healing does not. Fixed-ally pre-hit target substitution is implemented through
`BattleActionContext` and retained `EffectTargetSubstitution` bindings. TARGETED
responses update the attacker's live execution target before accuracy; effect nodes
remain on their owners. The latest valid binding wins, with recipient/cycle guards.
See the [target substitution plan](../../../editor_only_debug/markdown_documentation/Project%20Documentation/Historical%20Reference/Plans/Target%20Substitution%20Plan.md).

`BattleSkillGrantReconciler.reconcile(unit, ledger, stat_values)` validates a full
plan, then updates only owned sources. Unchanged passive components keep effect
instances; rank changes replace only that node's grants. External story/equipment
sources survive. Temporary chain suppression preserves cooldowns in the unit's
normal ticking map; stale generated action objects are rejected. Call `clear()`
before abandoning/replacing an adapter; freeing the RefCounted is not teardown.
Definitions are immutable for an adapter's lifetime; rebuild it after editing them.

`BattleUnitSkills` supplies authoritative stat snapshots and earned high-water
points. Relevant stat signals synchronously reconcile availability, with a busy
guard and bounded convergence checks. Cyclic self-gating grants fail closed and
report an authoring error; a rejected purchase rolls investment back without cost.
Only the exact active preparation lease owner can purchase through the party API.
The view revision changes with gates/earnings too, rejecting stale Apply callbacks.
Generated grants are excluded from ordinary Resource-path action saves, because
they are reconstructed from investment before saved pools/cooldowns. Known purchased
chains preserve cooldowns while suppressed; unknown saved IDs are ignored. Retry
restores investment and grant bookkeeping alongside baseline effects, without
replaying EQUIP. Legacy allocation conversion is not required: the user confirmed
that integration was abandoned. Production adoption/removal follows the current plan.

`BattleSkillPreparationView` renders authored tier/row positions and uses a single
cross-tree draft. Apply calls the party service; minus/Clear affect only uncommitted
choices. Requirement failures include current values and prerequisite locks.
Closing, switching units or a live gate change invalidates draft callbacks.
The view uses reusable authored tree pages, node details and per-tab scroll state.
Templates without a configured skill component have no purchasable tree UI.

The full-reset story entry is `do UIDirector.reset_story_skill_trees("unit_id")`.
It accepts a literal unit ID only during that exact executing Call in a story
state, outside preparation/combat/load/scene transitions. It clears spending
across every tree (without inflating earnings), removes tree grants/cooldowns,
and retains independent story/equipment sources. There is no ordinary reset UI.
Paid vendor/item systems must supply separate validated authority when implemented.

Celine's production collection includes Straight Punch (tier 1, visible row 3)
and Control (tier 3, visible row 5), both with five ranks. Control grants
+5/10/15/20/25% Lucidity capacity. Dark Urges exists as a separate authored node
but is not included in the tree. Harlok/goons use distinct empty collections.

Invalid persisted investment recovery is implemented in `BattleUnitSkills`:
reject the entire invalid payload, clear purchased ranks and derived grants/cooldowns,
and expose the existing earned allowance with zero spent. No points are added to
an old balance. Ordinary invalid purchase drafts remain non-destructive.
Broader skill content, manual UI/controller acceptance and balance remain separate
work; Yggdrasil removal and the production tree assignment are complete.

## Node strategy verification — 2026-09-20

Implemented the action/passive resource split and polymorphic payload dispatch.
Verified with Godot 4.7.2: strategy property isolation and dispatch, resource/save
round trips, mixed-chain rejection, and the existing investment, chain, unit-skills,
preparation, reset and turn-delay smoke suites. All seven suites completed without
script errors or assertion failures. Live MCP inspection confirmed both concrete
resource property lists and the abstract base. A temporary MCP editor test also
refreshed Control from disk and passed five assertions on its concrete type, ID,
rank count and modifier payload; the temporary test was removed. Headless shutdown reports 121
resources still in use; the unchanged baseline reports the same count.
Inspector creation helpers and rank-table editing remain planned, not implemented.
