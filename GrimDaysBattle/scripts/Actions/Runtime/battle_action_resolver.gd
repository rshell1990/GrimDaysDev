extends Node
## Validates an immutable [BattleActionRequest], pays its cost once, applies the
## action's effects in trigger order, and records individual resource-effect
## outcomes alongside action stages. Shared Spine timing carries animation tails between operations.
class_name BattleActionResolver

## Preloaded dependency used to construct or identify the combat event script.
const COMBAT_EVENT_SCRIPT := preload("res://GrimDaysBattle/scripts/Actions/Runtime/battle_combat_event.gd")
## Preloaded dependency used to construct or identify the action resolution script.
const ACTION_RESOLUTION_SCRIPT := preload(
    "res://GrimDaysBattle/scripts/Actions/Runtime/battle_action_resolution.gd"
)

## Emitted immediately after one event is appended to the active resolution.
signal combat_event_resolved(event)
## Live primitive outcomes for feedback during resolution.
signal operation_resolved(event: BattleCombatEvent)

## Re-entrancy guard; a resolver processes at most one request at a time.
var resolving: bool


## Resolves [param request] to completion. Rejected requests do not pay costs or
## apply effects and return an unsuccessful [BattleActionResolution].
func resolve(request, continuation: Callable = Callable(), timing: BattleActionContext = null):
    var resolution = ACTION_RESOLUTION_SCRIPT.new()
    resolution.request_id = request.request_id if request else &""
    var validation_error := _validate_request(request)
    if not validation_error.is_empty():
        resolution.error = validation_error
        return resolution
    if resolving:
        resolution.error = "Action resolver is already processing another request."
        return resolution

    resolving = true
    _add_event(resolution, COMBAT_EVENT_SCRIPT.TYPE.ACTION_STARTED, request)
    if _cancelled(continuation, resolution):
        return resolution
    if not request.free_action:
        if not request.actor.pay_action_cost(request.action):
            resolution.error = "Actor could not pay the action cost."
            resolving = false
            return resolution
        _add_event(resolution, COMBAT_EVENT_SCRIPT.TYPE.COST_PAID, request)

    var routing := BattleActionEffects.new(request, timing)
    if request.action is BattleMadnessAction:
        return await _resolve_madness_action(request, resolution, routing, continuation)
    if request.action is BattleItemAction:
        _add_event(
            resolution, COMBAT_EVENT_SCRIPT.TYPE.ITEM_USED, request, null, 1.0, {"item_id": request.action.item.id}
        )
    for target_index in routing.execution.targets.size():
        routing.execution.target_index = target_index
        var target_value: BattleUnit = routing.execution.targets[target_index]
        if _cancelled(continuation, resolution):
            return resolution
        var target: BattleUnit = target_value
        if not is_instance_valid(request.actor) or not request.actor.is_active:
            break
        if not CombatActions.valid_target(request.action, request.actor, target, request.madness_targeting):
            continue
        routing.execution.select(target)
        await _resolve_stage(
            routing, target, CombatEffects.TRIGGER.TARGETED, [target], request, resolution, continuation
        )
        if _cancelled(continuation, resolution):
            return resolution
        if not is_instance_valid(request.actor) or not request.actor.is_active:
            break
        target = routing.execution.current_target
        if not is_instance_valid(target) or not target.is_active:
            continue
        _add_event(resolution, COMBAT_EVENT_SCRIPT.TYPE.BEFORE_ATTACK, request, target)
        await _resolve_stage(
            routing, request.actor, CombatEffects.TRIGGER.ATTACKING, [target], request, resolution, continuation
        )
        if _cancelled(continuation, resolution):
            return resolution
        if not is_instance_valid(request.actor) or not request.actor.is_active:
            break
        target = routing.execution.current_target
        if not is_instance_valid(target) or not target.is_active:
            continue

        await _resolve_stage(
            routing, target, CombatEffects.TRIGGER.DAMAGED, [target], request, resolution, continuation
        )
        if _cancelled(continuation, resolution):
            return resolution
        target = routing.execution.current_target
        if not routing.hit_context.hit_or_non_damaging(target):
            continue
        # Hits install these before the damage mutation; non-damaging actions
        # have no accuracy gate and still grant their authored lifecycle effects.
        await routing.grant_lifecycle_effects(target)

    if is_instance_valid(request.actor):
        await _resolve_stage(
            routing,
            request.actor,
            CombatEffects.TRIGGER.PROCESS_OVER,
            routing.execution.targets,
            request,
            resolution,
            continuation
        )
    if _cancelled(continuation, resolution):
        return resolution

    await routing.execution.finish_animation(self, continuation)
    if _cancelled(continuation, resolution):
        return resolution

    # History may include a defeat followed by an authored revival. Only units
    # still defeated belong in the handoff to lifecycle/legacy phase consumers.
    resolution.defeated = resolution.defeated.filter(func(unit): return is_instance_valid(unit) and not unit.is_active)
    _add_event(resolution, COMBAT_EVENT_SCRIPT.TYPE.ACTION_FINISHED, request)
    resolution.success = true
    resolving = false
    return resolution


## A stopped/replaced encounter cannot resume mutation after an awaited effect.
func _cancelled(continuation: Callable, resolution: BattleActionResolution) -> bool:
    if continuation.is_valid() and not continuation.call():
        resolution.error = "Action encounter was cancelled."
        resolving = false
        return true
    return false


## Returns an empty string for a legal request or the first actionable error.
func _validate_request(request) -> String:
    if not request:
        return "Action request is null."
    if request.request_id.is_empty():
        return "Action request requires a request id."
    if not is_instance_valid(request.actor) or not request.actor.is_active:
        return "Action request requires an active actor."
    if not request.action:
        return "Action request has no action."
    if request.actor.is_stunned():
        return "Stunned units cannot act."
    var equipment_reason: String = request.action.get_equipment_unavailable_reason(request.actor)
    if not equipment_reason.is_empty():
        return equipment_reason
    if request.actor.is_action_disabled_by_effects(request.action):
        return "An active effect disables the requested action."
    if request.forced_action:
        if (
            not request.has_current_forced_source()
            or not request.action.get_rank_template(request.get_execution_rank())
        ):
            return "Forced action source is no longer active or its rank is invalid."
    elif request.lucidity_outcome:
        if (
            not request.actor.owns_action(request.action)
            or not request.action.get_rank_template(
                request.actor.get_action_rank(request.action, request.lucidity_outcome)
            )
        ):
            return "Lucidity outcome requires an owned skill with a valid rank."
    elif not request.actor.can_use_action(request.action):
        return "Actor does not own or cannot afford the requested action."
    if not (
        request
        . action
        . get_effects_by_rank_and_trigger(request.get_execution_rank(), CombatEffects.TRIGGER.EQUIP)
        . is_empty()
    ):
        return "EQUIP effects belong to equipment/passive grants, not combat actions."
    var targets: Array = request.targets
    if targets.is_empty():
        return "Action request has no targets."
    var unique_targets: Dictionary = {}
    for target_value in targets:
        var target: BattleUnit = target_value
        if not CombatActions.valid_target(request.action, request.actor, target, request.madness_targeting):
            return "Action request contains an invalid target."
        var target_id: int = target.get_instance_id()
        if unique_targets.has(target_id):
            return "Action request contains a duplicate target."
        unique_targets[target_id] = true
    if request.action.target in [CombatActions.TARGET.ALLY, CombatActions.TARGET.FOE]:
        if targets.size() > maxi(request.action.target_amount, 1):
            return "Action request exceeds the action target limit."
    return ""


## Capture each resource operation on all participants, including chain children,
## reactive sources and inactive units. Always disconnect before publishing events.
func _resolve_stage(
    routing: BattleActionEffects,
    stage_owner: BattleUnit,
    trigger: CombatEffects.TRIGGER,
    selected: Array[BattleUnit],
    request: BattleActionRequest,
    resolution: BattleActionResolution,
    continuation: Callable
) -> void:
    var observed: Array[BattleUnit] = [request.actor]
    observed.append_array(request.targets)
    var participants := CombatActions.get_participant_source(request.actor)
    if is_instance_valid(participants):
        if participants.has_method("get_participants"):
            observed.append_array(participants.get_participants())
        else:
            observed.append_array(participants.get_all_active_units())
    var was_active: Dictionary = {}
    for unit in observed:
        if is_instance_valid(unit):
            was_active[unit] = unit.is_active
    var capture := BattleResourceEventCapture.new(observed, request, &"", {"stage_trigger": trigger})
    capture.operation_resolved.connect(operation_resolved.emit)
    var operation_guard := continuation
    if trigger in [CombatEffects.TRIGGER.ATTACKING, CombatEffects.TRIGGER.TARGETED, CombatEffects.TRIGGER.DAMAGED]:
        operation_guard = func():
            return (
                is_instance_valid(request.actor)
                and request.actor.is_active
                and (not continuation.is_valid() or continuation.call())
            )
    await routing.resolve_stage(stage_owner, trigger, selected, operation_guard)
    capture.close()
    if continuation.is_valid() and not continuation.call():
        return
    for event in capture.events:
        resolution.add_event(event)
        combat_event_resolved.emit(event)
        if event.type == BattleCombatEvent.TYPE.DEFEAT and event.target not in resolution.defeated:
            resolution.defeated.append(event.target)
    # Non-resource operations (for example a maximum-Health modifier) can also
    # leave a unit inactive. Preserve defeat handoff without inventing damage.
    for unit in observed:
        if not is_instance_valid(unit):
            continue
        if was_active.get(unit, false) and not unit.is_active and unit not in resolution.defeated:
            resolution.defeated.append(unit)
            _add_event(resolution, COMBAT_EVENT_SCRIPT.TYPE.DEFEAT, request, unit)


## Stores and publishes one event so state and presentation share ordering.
func _add_event(
    resolution,
    type: int,
    request,
    target: BattleUnit = null,
    amount: float = 0.0,
    data: Dictionary = {},
) -> void:
    var event = COMBAT_EVENT_SCRIPT.new(type, request, target, amount, data)
    resolution.add_event(event)
    combat_event_resolved.emit(event)


## Stance/pass actions consume one turn and run completion hooks without attack/hit procs.
func _resolve_madness_action(
    request: BattleActionRequest,
    resolution: BattleActionResolution,
    routing: BattleActionEffects,
    continuation: Callable
) -> BattleActionResolution:
    if request.action.kind == BattleMadnessAction.KIND.COWER:
        request.actor.apply_cowering()
    _add_event(
        resolution, COMBAT_EVENT_SCRIPT.TYPE.MADNESS_ACTION, request, request.actor, 0.0, {"kind": request.action.kind}
    )
    await _resolve_stage(
        routing, request.actor, CombatEffects.TRIGGER.PROCESS_OVER, [request.actor], request, resolution, continuation
    )
    if _cancelled(continuation, resolution):
        return resolution
    await routing.execution.finish_animation(self, continuation)
    if _cancelled(continuation, resolution):
        return resolution
    _add_event(resolution, COMBAT_EVENT_SCRIPT.TYPE.ACTION_FINISHED, request)
    resolution.success = true
    resolving = false
    return resolution
