extends RefCounted
## Runs effects caused by round endings and defeats for this battle, without waiting for the screen
## display.
class_name BattleEncounterEffects

## Units whose defeat effects have already run. Revived units are removed from this record before
## checking for new defeats.
var _processed_defeats: Dictionary = {}


## Clears the record of processed defeats before a new battle starts.
func reset() -> void:
    _processed_defeats.clear()


## Runs and waits for defeat effects and the defeating unit's kill effects, including any further
## defeats they cause.
## Calls continuation to check whether the battle is still allowed to proceed.
## Returns ordered resource-operation events; the caller checks its attempt before publishing.
func process_defeats(
    roster: BattleEncounterRoster, continuation: Callable, request_id: StringName = &"", feedback: Callable = Callable()
) -> Array[BattleCombatEvent]:
    var capture := BattleResourceEventCapture.new(roster.get_participants(), null, request_id, {"lifecycle": true})
    _connect_feedback(capture, continuation, feedback)
    await _process_defeats(roster, continuation, _lifecycle_context())
    capture.close()
    return capture.events


## Shared defeat dispatch; round processing already owns an observer, so it calls
## this implementation directly to avoid recording hook operations twice.
func _process_defeats(roster: BattleEncounterRoster, continuation: Callable, context: Dictionary) -> void:
    # A defeat/kill hook may defeat another participant. Each unit is handled
    # at most once per pass so authored revival loops cannot spin indefinitely.
    var visited: Dictionary = {}
    for unit in roster.get_participants():
        if is_instance_valid(unit) and unit.is_active:
            _processed_defeats.erase(unit)
    for _pass in roster.get_participants().size():
        var found: bool = false
        for unit in roster.get_participants():
            if not continuation.call():
                return
            if not is_instance_valid(unit) or unit.is_active or unit in _processed_defeats or unit in visited:
                continue
            visited[unit] = true
            _processed_defeats[unit] = true
            found = true
            await resolve_unit_defeat(unit, continuation, context)
            if is_instance_valid(unit) and unit.is_active:
                _processed_defeats.erase(unit)
        if not found:
            break


## Runs round-end effects for units that can fight, counts down effect durations, then handles any
## resulting defeats.
## Calls continuation to check whether the battle is still allowed to proceed.
## Includes the resulting defeat/kill resource operations under the same capture.
func end_round(
    roster: BattleEncounterRoster, continuation: Callable, request_id: StringName = &"", feedback: Callable = Callable()
) -> Array[BattleCombatEvent]:
    var capture := BattleResourceEventCapture.new(roster.get_participants(), null, request_id, {"lifecycle": true})
    _connect_feedback(capture, continuation, feedback)
    await _end_round(roster, continuation)
    capture.close()
    return capture.events


## Resolves round operations, expiry and resulting hooks under one capture scope.
func _end_round(roster: BattleEncounterRoster, continuation: Callable) -> void:
    var context := _lifecycle_context()
    for unit in roster.get_all_active_units():
        if not continuation.call():
            return
        if is_instance_valid(unit) and unit.is_active:
            await unit.resolve_effects(CombatEffects.TRIGGER.ROUND_OVER, &"", continuation, context)
    if not continuation.call():
        return
    for unit in roster.get_participants():
        if is_instance_valid(unit) and roster.is_present(unit) and unit.effect_manager:
            unit.effect_manager.advance_round()
    await _process_defeats(roster, continuation, context)


## Delayed effects keep their originating unit even after its defeat. Every
## tick gets fresh accuracy/reaction state, never the previous cast's context.
func _lifecycle_context() -> Dictionary:
    return {
        "action_hit_context": BattleActionHitContext.new(null, false, true),
        "damage_reactions": BattleDamageReactions.new(),
        "allow_defeated_source": true
    }


## Completes one lethal operation after its DAMAGED window, before subsequent action effects.
## The legacy and production handoffs share these markers and cannot replay responses.
static func resolve_unit_defeat(unit: BattleUnit, continuation: Callable, context: Dictionary = {}) -> void:
    if not is_instance_valid(unit) or unit.is_active or unit.defeat_resolved:
        return
    if continuation.is_valid() and not continuation.call():
        return
    unit.defeat_resolved = true
    var scoped := context.duplicate(true)
    scoped["allow_defeated_source"] = true
    scoped["lifecycle"] = true
    scoped["action_hit_context"] = BattleActionHitContext.new(null, false, true)
    if not scoped.has("damage_reactions"):
        scoped["damage_reactions"] = BattleDamageReactions.new()
    await unit.resolve_effects(CombatEffects.TRIGGER.DEFEAT, &"", continuation, scoped)
    if not is_instance_valid(unit):
        return
    if unit.is_active:
        unit.defeat_resolved = false
        return
    if continuation.is_valid() and not continuation.call():
        return
    var participants := CombatActions.get_participant_source(unit)
    var units: Array = (
        participants.get_participants()
        if participants is BattleEncounterRoster
        else participants.get_all_active_units()
    )
    for owner: BattleUnit in units:
        for holder: EffectDirectors in owner.effect_manager.triggers_to_holders.values():
            for binding in holder.get_children():
                if binding is EffectTargetSubstitution and binding.bound_unit == unit:
                    binding.remove()
    unit.kill_resolved = true
    var killer := unit.last_hit_by as BattleUnit if is_instance_valid(unit.last_hit_by) else null
    if is_instance_valid(killer) and killer.is_active:
        await killer.resolve_effects(CombatEffects.TRIGGER.KILL, &"", continuation, scoped)


## Present a captured outcome before awaited lifecycle effects finish; stale attempts stay silent.
func _connect_feedback(capture: BattleResourceEventCapture, continuation: Callable, feedback: Callable) -> void:
    if not feedback.is_valid():
        return
    capture.operation_resolved.connect(
        func(event: BattleCombatEvent):
            if feedback.is_valid() and continuation.is_valid() and continuation.call():
                feedback.call(event)
    )
