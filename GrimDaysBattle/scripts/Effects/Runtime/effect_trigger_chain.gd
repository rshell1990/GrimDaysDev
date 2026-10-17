extends EffectBase
## Implements the runtime effect trigger chain behavior used by the battle effect pipeline.
class_name EffectTriggerChain

## Fixed max chain depth value shared by all effect trigger chain instances.
const MAX_CHAIN_DEPTH: int = 16

## Runtime effect template state used by this effect trigger chain.
var effect_template: EffectTriggerAnotherEffect


## Initializes this effect trigger chain from the supplied runtime dependencies.
func setup(sent_by: Variant, target_node: Variant, template: Variant) -> void:
    super(sent_by, target_node, template)
    effect_template = template


## Applies this effect trigger chain's configured behavior to its current target.
func apply() -> void:
    if not _begin_apply():
        return
    if not effect_template or sender is not BattleUnit or targeting is not BattleUnit:
        _finish_with_error("Effect chain %s requires BattleUnit sender and target." % id)
        return
    if effect_template.chance <= 0:
        _finish_apply()
        return
    if effect_template.chance < 100 and not sender.randomizer.percentage_roll(effect_template.chance):
        _finish_apply()
        return
    var context: Dictionary = get_meta(&"effect_chain_context", {}).duplicate(true)
    var path: Array = context.get("path", [])
    var depth: int = context.get("depth", 0)
    if path.is_empty():
        path.append(id)
    if depth >= MAX_CHAIN_DEPTH:
        CustomLogger.warn(self, apply, "Effect chain reached depth limit at %s." % id, CustomLogger.LEVEL.IMPORTANT)
        _finish_apply()
        return

    var minimum := clampi(effect_template.repeat_min, 1, 99)
    var maximum := clampi(effect_template.repeat_max, minimum, 99)
    var count: int = (
        minimum if minimum == maximum else sender.randomizer.random_number_generator.randi_range(minimum, maximum)
    )
    for repetition in count:
        if not can_continue_resolution():
            break
        await _apply_sequence(context, path, depth)
    _finish_apply()


## Each pass reapplies the same authored sequence in order, with independent damage rolls.
func _apply_sequence(context: Dictionary, path: Array, depth: int) -> void:
    for nested_template in effect_template.triggers:
        if not can_continue_resolution():
            break
        if not nested_template:
            continue
        if nested_template.id in path:
            CustomLogger.warn(
                self, apply, "Blocked cyclic effect chain at %s." % nested_template.id, CustomLogger.LEVEL.IMPORTANT
            )
            continue
        var child_context := {
            "depth": depth + 1,
            "path": path.duplicate(),
            "source_id": source_id,
            "continuation": resolution_continuation,
        }
        for key in [
            "action_hit_context",
            "damage_reactions",
            "action_operation",
            "after_hit_operation",
            "reaction_target",
            "reaction_trigger",
            "allow_defeated_source",
            "madness_targeting",
            "action_actor",
            "action_defender",
            "action_context",
            "action_router",
            "selected_target",
            "lifecycle",
            "expiry_recipient",
            "strike_followup"
        ]:
            if context.has(key):
                child_context[key] = context[key]
        child_context.path.append(nested_template.id)
        # Reaction chains address the incoming attacker/just-hit recipient,
        # without fabricating last_hit_by before damage has actually happened.
        var selected: BattleUnit = context.get("reaction_target", targeting)
        var execution: BattleActionContext = context.get("action_context")
        if (
            execution
            and not context.get("strike_followup", false)
            and not context.has("reaction_trigger")
            and (
                nested_template.target
                in [CombatActions.TARGET.DEFAULT, CombatActions.TARGET.ALLY, CombatActions.TARGET.FOE]
            )
        ):
            selected = execution.current_target
        var effect_targets := CombatActions.get_effect_target(
            sender, selected, nested_template, context.get("madness_targeting", false)
        )
        if (
            context.has("reaction_target")
            and (
                (
                    nested_template.target == CombatActions.TARGET.LAST_DAMAGED_BY
                    and context.get("reaction_trigger") == CombatEffects.TRIGGER.DAMAGED
                )
                or (
                    nested_template.target == CombatActions.TARGET.LAST_HIT
                    and context.get("reaction_trigger") == CombatEffects.TRIGGER.AFTER_HITTING
                )
            )
        ):
            effect_targets.clear()
            if is_instance_valid(selected):
                effect_targets.append(selected)
        # Expiry descendants cannot expand onto allies, foes, or the original sender.
        if context.has("expiry_recipient"):
            effect_targets.clear()
            if is_instance_valid(context.expiry_recipient):
                effect_targets.append(context.expiry_recipient)
        for expanded_target in effect_targets:
            var effect_target: BattleUnit = expanded_target
            var router_ref: WeakRef = context.get("action_router")
            if (
                not context.has("expiry_recipient")
                and not context.get("strike_followup", false)
                and router_ref
                and router_ref.get_ref()
                and not context.has("reaction_trigger")
            ):
                effect_target = await router_ref.get_ref().prepare_operation_target(
                    effect_target, nested_template.target, resolution_continuation
                )
            if not can_continue_resolution():
                break
            if (
                child_context.get("action_operation", false)
                and not child_context.has("reaction_trigger")
                and nested_template.target != CombatActions.TARGET.SELF
            ):
                child_context["action_defender"] = effect_target
            var child := (
                effect_target.call("add_effect", sender, effect_target, nested_template, child_context) as EffectBase
            )
            if not child:
                continue
            # A strike grants retained statuses; round/event behavior waits for its authored trigger.
            if (
                context.get("strike_followup", false)
                and nested_template.lifetime != EffectTemplate.LIFETIME.INSTANT
                and nested_template.trigger != CombatEffects.TRIGGER.EQUIP
            ):
                continue
            var applied_by_chain := false
            if not child.finished:
                child.resolve_application()
                applied_by_chain = child.applied_this_cycle
            # Cancellation or child removal must also wake the parent chain;
            # neither is guaranteed to emit the child's completion signal.
            while (
                is_instance_valid(child)
                and not child.is_queued_for_deletion()
                and (not child.finished or child.resolving_application)
                and can_continue_resolution()
            ):
                await get_tree().process_frame
            if is_instance_valid(child) and applied_by_chain:
                child.complete_trigger_cycle()


## Finishes with error for this effect trigger chain.
func _finish_with_error(message: String) -> void:
    CustomLogger.error(self, apply, message, CustomLogger.LEVEL.IMPORTANT)
    _finish_apply()
