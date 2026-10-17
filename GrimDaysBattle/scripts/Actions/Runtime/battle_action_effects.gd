extends RefCounted
## Applies the effects defined by one chosen action. The unit whose event is being processed
## also runs its usual passive effects; other recipients run only the effects this action gives
## them.
class_name BattleActionEffects

## Action request containing the acting unit, chosen action and an ID connecting its related events.
## The request cannot be edited after creation.
var _request: BattleActionRequest
## Effects available at the acting unit's skill rank, grouped by the event that activates them, such
## as a hit or defeat.
var _definitions: Dictionary = {}
## Records which effect has already been given to which unit for each event, to avoid giving it
## twice during one action.
var _granted: Dictionary = {}
## Remembers which units an effect targets, so an area or random target choice is not repeated for
## each hit.
var _expansions: Dictionary = {}
## Shared only by this cast's immediate damaging operations, including chains.
var hit_context: BattleActionHitContext
## Per-operation passive dispatcher, separate from authored operation buckets.
var damage_reactions: BattleDamageReactions
## Distinct after-hit scopes reroll proc targets once for each triggering hit.
var _hit_serial: int = 0
## Mutable execution targets and TARGETED response history for this action.
## Original request selections remain unchanged when a retained binding substitutes a target.
var execution := BattleActionContext.new()


## Looks up the skill's effects at the acting unit's current rank and groups them by the events that
## activate them.
func _init(request: BattleActionRequest, timing: BattleActionContext = null) -> void:
    if timing:
        execution = timing
    _request = request
    execution.attacker = request.actor
    execution.targets.assign(request.targets)
    hit_context = BattleActionHitContext.new(self, request.action.always_hits)
    damage_reactions = BattleDamageReactions.new(self)
    var rank := request.get_execution_rank()
    for trigger in CombatEffects.TRIGGER.values():
        _definitions[trigger] = request.action.get_effects_by_rank_and_trigger(rank, trigger)


## Gives each defined effect to each receiving unit at most once per action,
## even when several selected targets lead to the same self-targeted or area effect.
## Returns the newly created effects grouped by the unit receiving them.
func grant(
    trigger: CombatEffects.TRIGGER,
    selected: Array[BattleUnit],
    scope: String = "",
    continuation: Callable = Callable(),
    only_index: int = -1
) -> Dictionary:
    var grants: Dictionary = {}
    var definitions: Array = _definitions.get(trigger, [])
    for index in definitions.size():
        if only_index >= 0 and index != only_index:
            continue
        var definition: EffectTemplate = definitions[index]
        if not definition:
            continue
        for selected_value in selected:
            var selected_target: BattleUnit = selected_value
            if (
                trigger in [CombatEffects.TRIGGER.ATTACKING, CombatEffects.TRIGGER.DAMAGED]
                and (
                    definition.target
                    in [
                        CombatActions.TARGET.DEFAULT,
                        CombatActions.TARGET.ALLY,
                        CombatActions.TARGET.FOE,
                    ]
                )
                and not CombatActions.is_group_target(_request.action.target)
                and is_instance_valid(execution.current_target)
            ):
                selected_target = execution.current_target
            if not is_instance_valid(selected_target):
                continue
            var expansion_key := "%s:%s:%s" % [scope, trigger, index]
            # Explicit selected-target policies vary per hit. Area/random policies
            # describe one cast and must not expand/reroll for every selected target.
            if (
                (
                    definition.target
                    in [
                        CombatActions.TARGET.DEFAULT,
                        CombatActions.TARGET.ALLY,
                        CombatActions.TARGET.FOE,
                        CombatActions.TARGET.LAST_HIT
                    ]
                )
                or (
                    _request.madness_targeting
                    and (
                        definition.target
                        not in [
                            CombatActions.TARGET.ALLIES,
                            CombatActions.TARGET.FOES,
                            CombatActions.TARGET.ALL,
                            CombatActions.TARGET.OTHERS
                        ]
                    )
                )
            ):
                expansion_key += ":%s" % selected_target.get_instance_id()
            if not _expansions.has(expansion_key):
                _expansions[expansion_key] = CombatActions.get_effect_target(
                    _request.actor, selected_target, definition, _request.madness_targeting
                )
            for expanded: BattleUnit in _expansions[expansion_key]:
                var recipient := expanded
                if trigger in [CombatEffects.TRIGGER.ATTACKING, CombatEffects.TRIGGER.DAMAGED]:
                    recipient = await prepare_operation_target(
                        recipient, definition.target, continuation
                    )
                if not is_instance_valid(recipient):
                    continue
                var key := "%s:%s:%s:%s" % [scope, trigger, index, recipient.get_instance_id()]
                if _granted.has(key):
                    continue
                _granted[key] = true
                # Stable across casts, but isolated from other actions/equipment.
                var source := StringName(
                    "action:%s:%s:%s:%s"
                    % [_request.actor.get_instance_id(), _request.action.id, trigger, index]
                )
                var context := {
                    "source_id": source,
                    "defer_application": true,
                    "action_operation": true,
                    "madness_targeting": _request.madness_targeting,
                    "action_actor": _request.actor,
                    "action_defender":
                    (
                        execution.current_target
                        if definition.target == CombatActions.TARGET.SELF
                        else recipient
                    ),
                    "selected_target": selected_target,
                    "action_context": execution,
                    "action_router": weakref(self)
                }
                if not scope.is_empty():
                    context["after_hit_operation"] = true
                if (
                    trigger
                    not in [
                        CombatEffects.TRIGGER.DEFEAT,
                        CombatEffects.TRIGGER.KILL,
                        CombatEffects.TRIGGER.ROUND_OVER,
                    ]
                ):
                    context["action_hit_context"] = hit_context
                    context["damage_reactions"] = damage_reactions
                var effect: EffectBase = recipient.add_effect(
                    _request.actor, recipient, definition, context
                )
                if is_instance_valid(effect):
                    if not grants.has(recipient):
                        grants[recipient] = []
                    grants[recipient].append(effect)
    return grants


## Adds effects for this action step and waits for them to run. The owner also runs its usual
## passive effects.
## Other units run only the effects just added to them. Returns reports identifying the receiving
## unit.
## If supplied, continuation is called to check whether processing may continue.
func resolve_stage(
    owner: BattleUnit,
    trigger: CombatEffects.TRIGGER,
    selected: Array[BattleUnit],
    continuation: Callable,
    run_passives: bool = true,
    scope: String = ""
) -> Array[Dictionary]:
    var reports: Array[Dictionary] = []
    if continuation.is_valid() and not continuation.call():
        return reports
    if trigger == CombatEffects.TRIGGER.TARGETED:
        if CombatActions.is_group_target(_request.action.target):
            return reports
        execution.select(owner)
        if not is_instance_valid(owner) or execution.targeted.has(owner):
            return reports
        execution.targeted[owner] = true
        execution.response_owner = owner
        execution.targeting_response = true
        await damage_reactions.ensure_targeted(_request.actor, owner, continuation)
        execution.targeting_response = false
        execution.response_owner = null
        if continuation.is_valid() and not continuation.call():
            return reports
        if execution.current_target != owner:
            owner.action_substituted.emit(
                {
                    "source": _request.actor,
                    "recipient": execution.current_target,
                    "original_selection": owner,
                    "resolved_change": 0.0
                }
            )
        selected = [execution.current_target]
        run_passives = false
    # Incoming-damage and after-hit passives now run per primitive operation.
    # This stage executes only the authored operations, avoiding replay/recursion.
    if trigger in [CombatEffects.TRIGGER.DAMAGED, CombatEffects.TRIGGER.AFTER_HITTING]:
        run_passives = false
    if run_passives and is_instance_valid(owner):
        var request_id := await owner.resolve_effects(
            trigger, _request.request_id, continuation, {"action_context": execution}
        )
        if is_instance_valid(owner):
            var resolution_reports := owner.effect_manager.take_resolution_reports(request_id)
            _append_reports(reports, owner, resolution_reports)
    for index in _definitions.get(trigger, []).size():
        if continuation.is_valid() and not continuation.call():
            break
        var grants := await grant(trigger, selected, scope, continuation, index)
        for recipient: BattleUnit in grants:
            if continuation.is_valid() and not continuation.call():
                break
            if not is_instance_valid(recipient):
                continue
            var holder: EffectDirectors = recipient.effect_manager.triggers_to_holders.get(trigger)
            var effects: Array[Node] = []
            effects.assign(grants[recipient])
            var request_id := recipient.create_effect_request_id(trigger, _request.request_id)
            await holder.trigger_selected_effects(request_id, effects, continuation)
            if is_instance_valid(holder) and is_instance_valid(recipient):
                _append_reports(reports, recipient, holder.last_resolution_reports)
    return reports


## Resolve genuine individual selections before creating effect nodes on their final owners.
## The replacement is already current and must not receive a synthesized TARGETED response.
func prepare_operation_target(
	target: BattleUnit, mode: CombatActions.TARGET, continuation: Callable
) -> BattleUnit:
    if (
        CombatActions.is_group_target(mode)
        or CombatActions.is_group_target(_request.action.target)
        or mode == CombatActions.TARGET.SELF
    ):
        return target
    var explicit_random := (
        mode
        in [
            CombatActions.TARGET.RANDOM_ALL,
            CombatActions.TARGET.RANDOM_ALLY,
            CombatActions.TARGET.RANDOM_FOE,
            CombatActions.TARGET.RANDOM_OTHER
        ]
    )
    if target == execution.current_target and not explicit_random:
        return target
    await resolve_stage(target, CombatEffects.TRIGGER.TARGETED, [target], continuation)
    return execution.current_target


## Authored AFTER_HITTING operations are scoped to the primitive's actual
## recipient, not the composite's original target list. A proc's own damage
## cannot recursively schedule another copy of the same authored proc list.
func resolve_after_hit(operation: EffectBase) -> void:
    var context: Dictionary = operation.get_meta(EffectBase.CHAIN_CONTEXT_META, {})
    if (
        context.get("action_hit_context") != hit_context
        or context.get("after_hit_operation", false)
    ):
        return
    _hit_serial += 1
    await resolve_stage(
        _request.actor,
        CombatEffects.TRIGGER.AFTER_HITTING,
        [operation.targeting as BattleUnit],
        operation.resolution_continuation,
        false,
        "hit:%s" % _hit_serial
    )


## Adds effects that will run on defeat, kill or round end; does not run them yet.
func grant_lifecycle_effects(target: BattleUnit) -> void:
    var triggers := [
        CombatEffects.TRIGGER.DEFEAT,
        CombatEffects.TRIGGER.KILL,
        CombatEffects.TRIGGER.ROUND_OVER,
    ]
    for trigger in triggers:
        await grant(trigger, [target])


## Adds copies of effect reports to the output list, copying nested data and recording which unit
## received each effect.
func _append_reports(output: Array[Dictionary], recipient: BattleUnit, reports: Array) -> void:
    for report: Dictionary in reports:
        var entry := report.duplicate(true)
        entry["recipient"] = recipient
        output.append(entry)
