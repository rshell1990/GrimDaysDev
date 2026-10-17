extends Node
## Permanent-unit integration for project-owned skill purchases and derived grants.
## The party service authorizes commands; this component supplies authoritative
## earnings/current stats and owns save/retry reconstruction. Definitions are never
## mutated. Legacy addon allocations are deliberately not interpreted here.
class_name BattleUnitSkills

## Emitted when the view revision changes after skill state or availability updates.
signal changed

## Bounds gate/grant stabilization so oscillating passive requirements fail safely.
const MAX_REFRESH_PASSES: int = 16
const DEFINITION_SIGNATURE = preload(
    "res://GrimDaysBattle/scripts/Skills/Runtime/skill_definition_signature.gd"
)

## Unit-owned purchased ranks and shared skill-point accounting.
var ledger := BattleSkillInvestment.new()
## View revision also changes when gates/earnings change, not just purchases.
var revision: int = 0
## Temporarily prevents automatic reconciliation during coordinated restoration.
var suspended: bool = false
## Runtime unit providing stats, earnings and grant ownership.
var _unit: BattleUnit
## Shared immutable collection used to configure candidate ledgers.
var _definitions: BattleSkillTreeCollection
## Adapter responsible for this component's compiled action and passive grants.
var _grants := BattleSkillGrantReconciler.new()
## Set of stat IDs referenced by any tier or node requirement.
var _gate_ids: Dictionary = {}
## Gate values observed at the last completed refresh.
var _last_gates: Dictionary = {}
## Guards purchase/refresh operations against recursive callbacks.
var _busy: bool = false
## Whether initialization and required-stat checks succeeded.
var _configured: bool = false
## Authored gameplay data used when this runtime unit was constructed.
var _definition_signature: String = ""


## Configures the ledger once, validates payloads and required unit stats, subscribes to
## gate/earnings changes, then reconciles grants. Returns collected errors to the caller.
func initialize(unit: BattleUnit, definitions: BattleSkillTreeCollection) -> PackedStringArray:
    if _configured:
        return PackedStringArray(["Unit skills are already initialized."])
    var errors := ledger.configure(definitions)
    if not errors.is_empty():
        return errors
    errors = BattleSkillPayloadValidator.validate(ledger.get_nodes())
    if not errors.is_empty():
        return errors
    _unit = unit
    _definitions = definitions
    _definition_signature = DEFINITION_SIGNATURE.for_collection(definitions)
    for tree in definitions.trees:
        for definition in tree.get_runtime_tiers() + tree.get_nodes():
            for bounds in [definition.minimum_stats, definition.maximum_stats]:
                for stat in bounds:
                    _gate_ids[stat] = true
    for stat in _gate_ids:
        if not unit.get_stat(stat):
            errors.append("Skill requirement stat is missing: %s." % CombatStats.get_stat_as_string(stat))
    if not errors.is_empty():
        return errors
    _configured = true
    # Defaults use the ordinary atomic purchase path, including earnings, gates and payload preflight.
    # Saves/retries subsequently replace this ledger; an empty saved investment stays empty.
    if definitions.default_assignment and not definitions.default_assignment.ranks.is_empty():
        errors = purchase(definitions.default_assignment.ranks, revision)
        if not errors.is_empty():
            _configured = false
            return errors
    definitions.warn_empty_tiers()
    for stat in _gate_ids:
        unit.get_stat(stat).value_changed.connect(_on_stat_changed)
    unit.attribute_points_changed.connect(_on_earnings_changed)
    return refresh()


## High-water earnings cannot be reduced by temporary Level penalties.
func earned_points() -> int:
    return (
        BattleAttributeProgression.grants(_unit, int(_unit.attribute_progression.get("highest_level", 0))).skill
        if _configured
        else 0
    )


## Returns current values for all unit stats, or an empty dictionary before configuration.
func stat_values() -> Dictionary:
    var values: Dictionary = {}
    if _configured:
        for stat: UnitGenericStat in _unit.stat_dictionary.values():
            values[stat.id] = stat.Current
    return values


## Returns the current view revision, earned/spent/available point totals and an independent rank
## dictionary for preparation UI.
func snapshot() -> Dictionary:
    return {
        "revision": revision,
        "earned": earned_points(),
        "spent": ledger.spent_points(),
        "available": ledger.available_points(earned_points()),
        "ranks": ledger.capture().ranks
    }


## Validate a disposable draft, including its compiled payload, before committing.
## Only the party's lease-checked entry point should call this command.
func purchase(additions: Dictionary, expected_revision: int) -> PackedStringArray:
    if not _configured or suspended or _busy or expected_revision != revision:
        return PackedStringArray(["Invalid or stale unit skill purchase."])
    var candidate := BattleSkillInvestment.new()
    candidate.configure(_definitions)
    candidate.restore(ledger.capture(), earned_points())
    var errors := candidate.purchase(additions, earned_points(), stat_values(), candidate.revision)
    if errors.is_empty():
        errors = _grants.validate_plan(_unit, candidate, stat_values())
    if not errors.is_empty():
        return errors
    var before := ledger.capture()
    errors = ledger.purchase(additions, earned_points(), stat_values(), ledger.revision)
    if errors.is_empty():
        errors = refresh()
    if not errors.is_empty():
        # Bad authored feedback must not charge the player for a rejected purchase.
        ledger.restore(before, earned_points())
        refresh()
    return errors


## Synchronous gate updates keep combat queries current. Signals raised by our
## own grants never re-enter reconciliation. Detect oscillation or unbounded
## self-buffs, revoke only these tree grants and report an authoring error instead
## of recursively hanging combat. Purchases remain intact for diagnosis/recovery.
func refresh() -> PackedStringArray:
    if not _configured or suspended or _busy:
        return []
    _busy = true
    var seen: Array[Dictionary] = []
    var errors := PackedStringArray()
    for attempt in MAX_REFRESH_PASSES:
        var before := _gate_values()
        if seen.has(before):
            errors.append("Skill grants form a cyclic availability feedback loop.")
            break
        seen.append(before)
        errors = _grants.reconcile(_unit, ledger, stat_values())
        if not errors.is_empty() or before == _gate_values():
            break
        if attempt == MAX_REFRESH_PASSES - 1:
            errors.append("Skill availability did not stabilize within the safety limit.")
    if not errors.is_empty():
        _grants.clear()
    _last_gates = _gate_values()
    revision += 1
    _busy = false
    changed.emit()
    return errors


## Captures only stats referenced by tier or node gates for refresh-change detection.
func _gate_values() -> Dictionary:
    var values: Dictionary = {}
    for id in _gate_ids:
        values[id] = _unit.get_stat(id).Current
    return values


## Reconciles and reports errors when gate values change outside suspension or an existing refresh.
func _on_stat_changed(_stat: UnitGenericStat, _old: float, _new: float) -> void:
    if not suspended and not _busy and _gate_values() != _last_gates:
        _report(refresh())


## Refreshes availability after progression changes unless updates are suspended or already in
## progress.
func _on_earnings_changed() -> void:
    if not suspended and not _busy:
        _report(refresh())


## Logs each refresh error through CustomLogger at IMPORTANT level.
func _report(errors: PackedStringArray) -> void:
    for error in errors:
        CustomLogger.error(self, refresh, error, CustomLogger.LEVEL.IMPORTANT)


## Known purchased chains retain cooldowns even if all their tiers are suppressed.
## Unknown IDs from a save never become executable or acquire ownership.
func owns_chain(action_id: StringName) -> bool:
    for node in ledger.get_nodes():
        if node.has_action_source() and node.previous_node.is_empty() and ledger.get_rank(node.id) > 0:
            var id := StringName(
                (
                    BattleSkillChainResolver.SOURCE_PREFIX
                    + JSON.stringify([String(ledger.get_tree_id(node.id)), String(node.id)])
                )
            )
            if action_id == id:
                return true
    return false


## Saves versioned ranks plus the authored-definition signature; runtime grants are reconstructed.
func capture() -> Dictionary:
    var data := ledger.capture()
    data["definition_signature"] = _definition_signature
    return data


## Internal command for an authorized story/vendor/item boundary, never a normal
## preparation action. Refund means clearing spending, not increasing earnings.
## Story/equipment grants are independent; only purchased tree grants disappear.
func reset_all_from_authorized_source(expected_revision: int) -> int:
    if not _configured or suspended or _busy or revision != expected_revision:
        return -1
    _busy = true
    for id in _unit._action_cooldowns.keys():
        if owns_chain(id):
            _unit._action_cooldowns.erase(id)
    _grants.clear()
    var refunded := ledger.reset_all(ledger.revision)
    _busy = false
    refresh()
    return refunded


## Clear old derived grants before the party replaces action/stat ownership.
func begin_restore() -> void:
    suspended = true
    _grants.clear()


## Attribute earnings and flat bases must already be restored. Current resource
## pools/cooldowns follow this call, so they see reconstructed maximums/ownership.
## Invalid saved investment clears all purchased ranks and tree-derived grants,
## exposing the earned allowance as unspent; returned errors report that recovery.
func restore(data: Variant) -> PackedStringArray:
    var errors := PackedStringArray()
    # Legacy nonempty ledgers have no evidence of the definitions they purchased.
    # Refund once rather than silently accepting a potentially changed build.
    if (
        data is Dictionary
        and data.get("ranks") is Dictionary
        and not data.ranks.is_empty()
        and data.get("definition_signature", "") != _definition_signature
    ):
        errors.append("Skill definitions changed or were not recorded; all skill points are available to reassign.")
    else:
        errors = ledger.restore(data, earned_points())
    if not errors.is_empty():
        _clear_invalid_investment()
    suspended = false
    errors.append_array(refresh())
    return errors


## Invalid persisted investment refunds by clearing spending, never by adding points.
## Source prefixes are reserved for derived tree grants, including suppressed chains.
func _clear_invalid_investment() -> void:
    var was_suspended := suspended
    suspended = true
    _grants.clear()
    for source in _unit._action_grants_by_source.keys():
        if String(source).begins_with(BattleSkillChainResolver.SOURCE_PREFIX):
            _unit.revoke_action_source(source)
    for id in _unit._action_cooldowns.keys():
        if String(id).begins_with(BattleSkillChainResolver.SOURCE_PREFIX):
            _unit._action_cooldowns.erase(id)
    for stat: UnitGenericStat in _unit.stat_dictionary.values():
        var sources: Dictionary = {}
        for modifier: UnitStatModifier in stat.mods.values():
            if String(modifier.source_id).begins_with(BattleSkillChainResolver.SOURCE_PREFIX):
                sources[modifier.source_id] = true
        for source in sources:
            stat.remove_modifiers_from_source(source)
    for holder: EffectDirectors in _unit.effect_manager.triggers_to_holders.values():
        for effect in holder.get_children():
            if effect is EffectBase and String(effect.source_id).begins_with(BattleSkillChainResolver.SOURCE_PREFIX):
                effect.remove()
    ledger.reset_all(ledger.revision)
    suspended = was_suspended


## Captures investments and grant-adapter bookkeeping for coordinated runtime retry restoration.
func capture_retry_state() -> Dictionary:
    return {"investment": ledger.capture(), "grants": _grants.capture_retry_state()}


## Adopt checkpoint-restored grant bookkeeping without firing EQUIP again.
func restore_retry_state(state: Dictionary) -> bool:
    var errors := ledger.restore(state.get("investment"), earned_points())
    if not errors.is_empty():
        _clear_invalid_investment()
        suspended = false
        for error in errors:
            CustomLogger.warn(self, restore_retry_state, error, CustomLogger.LEVEL.IMPORTANT)
        return refresh().is_empty()
    _grants.restore_retry_state(_unit, ledger, state.grants)
    _last_gates = _gate_values()
    revision += 1
    suspended = false
    changed.emit()
    return true
