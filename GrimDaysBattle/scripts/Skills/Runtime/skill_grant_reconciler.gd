extends RefCounted
## Applies compiled plans to one unit, touching only sources this adapter owns.
## The permanent-party adapter (next stage) supplies authoritative stat snapshots
## and calls reconcile after investment/availability changes. No automatic signal
## feedback loop is installed here; callbacks cannot re-enter a transaction.
class_name BattleSkillGrantReconciler

## Weak reference to the runtime unit receiving this adapter's grants.
var _unit: WeakRef
## Investment ledger from which the current grants are derived.
var _ledger: BattleSkillInvestment
## Compiled action entries currently owned by this adapter, keyed by source.
var _actions: Dictionary = {}
## Passive node/rank entries currently applied by this adapter.
var _passives: Dictionary = {}
## Generated action IDs whose cooldowns remain owned even while gates suppress them.
var _cooldown_ids: Dictionary = {}
## Prevents reentrant grant mutation while a reconciliation is in progress.
var _busy: bool = false


## Read-only validation lets the party adapter reject a proposed purchase before
## changing its investment ledger or publishing any combat grants.
func validate_plan(unit: BattleUnit, ledger: BattleSkillInvestment, values: Dictionary) -> PackedStringArray:
    var plan := BattleSkillChainResolver.resolve(ledger, values)
    return plan.errors if not plan.errors.is_empty() else _preflight(unit, plan)


## In-memory retry bookkeeping only. The checkpoint restores actual action,
## modifier and effect state separately, without replaying passive operations.
func capture_retry_state() -> Dictionary:
    return {
        "actions": _actions.duplicate(true),
        "passives": _passives.duplicate(true),
        "cooldown_ids": _cooldown_ids.duplicate()
    }


## Rebinds the unit and ledger and copies the checkpoint's adapter bookkeeping. The retry
## coordinator restores the actual runtime grants separately.
func restore_retry_state(unit: BattleUnit, ledger: BattleSkillInvestment, state: Dictionary) -> void:
    _unit = weakref(unit)
    _ledger = ledger
    _actions = state.actions.duplicate(true)
    _passives = state.passives.duplicate(true)
    _cooldown_ids = state.cooldown_ids.duplicate()


## Validates the complete plan before changing grants. Unchanged components keep
## the same effect instances: refreshes never replay EQUIP or reset their state.
func reconcile(unit: BattleUnit, ledger: BattleSkillInvestment, stat_values: Dictionary) -> PackedStringArray:
    if _busy or not is_instance_valid(unit) or not unit.is_inside_tree() or not unit.effect_manager:
        return PackedStringArray(["Skill grants require a live unit and a non-reentrant update."])
    if _unit and (_unit.get_ref() != unit or _ledger != ledger):
        return PackedStringArray(["A skill grant adapter belongs to one unit and investment ledger."])
    var plan := BattleSkillChainResolver.resolve(ledger, stat_values)
    if not plan.errors.is_empty():
        return plan.errors
    var errors := _preflight(unit, plan)
    if not errors.is_empty():
        return errors
    _unit = weakref(unit)
    _ledger = ledger
    _busy = true
    for source in _actions.keys():
        if not plan.actions.has(source):
            # Suppression is not an ownership refund. Preserve remaining cooldown in
            # the unit's normal ticking ledger, including while no tier is available.
            var id: StringName = _actions[source].action.id
            var cooldown: int = unit._action_cooldowns.get(id, 0)
            unit.revoke_action_source(source)
            if cooldown > 0:
                unit._action_cooldowns[id] = cooldown
            _actions.erase(source)
    for source in _passives.keys():
        if not plan.passives.has(source) or not _same_passive(_passives[source], plan.passives[source]):
            _remove_passive(unit, source)
            _passives.erase(source)
    for source in plan.actions:
        var entry: Dictionary = plan.actions[source]
        if _actions.has(source) and _actions[source].signature == entry.signature:
            continue
        unit.grant_action_from_source(source, entry.action, entry.rank)
        _cooldown_ids[entry.action.id] = true
        _actions[source] = entry
    for source in plan.passives:
        if _passives.has(source):
            continue
        var entry: Dictionary = plan.passives[source]
        var node: BattleSkillPassiveNode = entry.node
        node.apply_grants(unit, entry.rank, source)
        _passives[source] = entry
    _busy = false
    return []


## Teardown revokes only this adapter's grants, not other story/equipment sources.
## Call before replacing the adapter; free of this RefCounted alone is not cleanup.
func clear() -> bool:
    if _busy:
        return false
    _busy = true
    var unit: BattleUnit = _unit.get_ref() if _unit else null
    if is_instance_valid(unit):
        for source in _actions:
            unit.revoke_action_source(source)
        # Includes currently suppressed chains whose cooldowns keep ticking.
        for id in _cooldown_ids:
            unit._action_cooldowns.erase(id)
        for source in _passives:
            _remove_passive(unit, source)
    _actions.clear()
    _passives.clear()
    _cooldown_ids.clear()
    _unit = null
    _ledger = null
    _busy = false
    return true


## Rejects foreign ownership of planned action/passive sources and missing cost or modifier stats
## before any grants change.
func _preflight(unit: BattleUnit, plan: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    for source in plan.actions:
        if not _actions.has(source) and unit._action_grants_by_source.has(source):
            errors.append("Skill action source is already owned by another adapter.")
        var entry: Dictionary = plan.actions[source]
        for stat in entry.action.get_rank_template(entry.rank).cost:
            if not unit.get_stat(stat):
                errors.append("Unit lacks a composite action cost stat.")
    for source in plan.passives:
        if not _passives.has(source):
            if not unit.effect_manager.get_effects_from_source(source).is_empty():
                errors.append("Skill passive effect source is already owned.")
            for stat: UnitGenericStat in unit.stat_dictionary.values():
                if not stat.get_modifiers_from_source(source).is_empty():
                    errors.append("Skill passive stat source is already owned.")
        var node: BattleSkillPassiveNode = plan.passives[source].node
        node.validate_grant_stats(unit, errors)
    return errors


## Returns whether the passive still references the same authored node and purchased rank, so its
## runtime instances can be retained.
static func _same_passive(before: Dictionary, after: Dictionary) -> bool:
    return before.node == after.node and before.rank == after.rank


## Removes only modifiers and effects carrying this passive's source ID from the unit.
static func _remove_passive(unit: BattleUnit, source: StringName) -> void:
    for stat: UnitGenericStat in unit.stat_dictionary.values():
        stat.remove_modifiers_from_source(source)
    unit.effect_manager.remove_effects_from_source(source)
