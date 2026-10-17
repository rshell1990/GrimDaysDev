extends Node
#region EFFECT DIRECTORS
## The base class that specific effect directors will derive from.
class_name EffectDirectors

#endregion
## Emitted when effects triggered.
signal effects_triggered(request_id: StringName)
#region VARIABLES
## Holds the incoming effect so tha the derived classes can access the effect to additionally manipulate it.
var incoming_effect
## Immutable reports collected from effects during the most recent trigger call.
var last_resolution_reports: Array[Dictionary]

#endregion

#region MAIN


## Returns attached for this effect directors.
func get_attached() -> Node:
    return get_parent().get_attached() if get_parent().has_method("get_attached") else get_parent()


## Adds the basic sequence to add an effect to the director, will be further refined by classes that derive from this
## base class.
func add_effect(sender: Node, target: Node, template: EffectTemplate, context: Dictionary = {}) -> EffectBase:
    incoming_effect = null
    var count: int = 0
    var new_name: StringName = template.id + "_" + str(count)
    var requested_source_id := StringName(
        (
            context
            . get(
                "source_id",
                "runtime_source:%s" % sender.get_instance_id() if sender else template.id,
            )
        )
    )

    var same_effect := get_effect(template.id, requested_source_id, template.stacking_across_sources)
    if same_effect:
        match same_effect.stacking:
            EffectTemplate.STACKING.REPLACE:
                # Revoke the old modifier/snapshot without firing expiry children.
                same_effect.remove()
            EffectTemplate.STACKING.DISCARD:
                # Return no grant so callers cannot apply the blocked incoming effect.
                return null
            EffectTemplate.STACKING.REFRESH, EffectTemplate.STACKING.COMBINE:
                if same_effect.stacking == EffectTemplate.STACKING.COMBINE:
                    same_effect.duration += same_effect.max_duration
                else:
                    same_effect.duration = same_effect.max_duration
                var refreshed_context := context.duplicate()
                refreshed_context["source_id"] = same_effect.source_id
                same_effect.set_chain_context(refreshed_context)
                incoming_effect = same_effect
                return same_effect

    while new_name in get_meta_list():
        count += 1
        new_name = template.id + "_" + str(count)

    if not template.template_scene:
        CustomLogger.error(
            self, add_effect, "Effect %s has no runtime template scene." % template.id, CustomLogger.LEVEL.IMPORTANT
        )
        return null
    incoming_effect = template.template_scene.instantiate()
    if incoming_effect is not EffectBase:
        CustomLogger.error(
            self,
            add_effect,
            "Effect %s runtime scene must inherit EffectBase." % template.id,
            CustomLogger.LEVEL.IMPORTANT
        )
        incoming_effect.queue_free()
        incoming_effect = null
        return null
    incoming_effect.name = new_name
    incoming_effect.setup(sender, target, template)
    incoming_effect.set_chain_context(context)
    add_child(incoming_effect)
    # A chain owns its children's trigger cycle so an instant child is not applied
    # once here and a second time by EffectTriggerChain.
    if template.lifetime == EffectTemplate.LIFETIME.INSTANT and context.is_empty():
        incoming_effect.apply()
        incoming_effect.complete_trigger_cycle()
    return incoming_effect


## Triggers effects for this effect directors.
func trigger_effects(request_id: StringName, continuation: Callable = Callable(), context: Dictionary = {}) -> void:
    await trigger_selected_effects(request_id, get_children(), continuation, context)


## Explicit action recipients must not fire unrelated passive effects merely
## because an action operation was routed into their trigger bucket.
func trigger_selected_effects(
    request_id: StringName, effects: Array[Node], continuation: Callable = Callable(), context: Dictionary = {}
) -> void:
    last_resolution_reports.clear()
    CustomLogger.hint(self, trigger_effects, name + " triggered.", CustomLogger.LEVEL.VERBOSE)
    CustomLogger.hint(self, trigger_effects, "Queued effects: " + str(effects), CustomLogger.LEVEL.VERY_VERBOSE)
    for effect in effects:
        if continuation.is_valid() and not continuation.call():
            break
        if not is_instance_valid(effect) or effect.is_queued_for_deletion():
            continue
        CustomLogger.hint(self, trigger_effects, "Applying - " + str(effect), CustomLogger.LEVEL.VERBOSE)
        var original: Dictionary = effect.get_meta(EffectBase.CHAIN_CONTEXT_META, {})
        var original_guard: Callable = effect.resolution_continuation
        if not context.is_empty():
            var scoped := original.duplicate(true)
            scoped.merge(context, true)
            effect.set_chain_context(scoped)
        effect.resolution_continuation = continuation
        effect.resolve_application()
        while (
            is_instance_valid(effect)
            and not effect.is_queued_for_deletion()
            and (not effect.finished or effect.resolving_application)
            and (not continuation.is_valid() or continuation.call())
        ):
            await get_tree().process_frame
        if not is_instance_valid(effect):
            continue
        # Context belongs to this dispatch, not to the retained effect's next tick.
        effect.set_chain_context(original)
        effect.resolution_continuation = original_guard
        if continuation.is_valid() and not continuation.call():
            break
        var report: Dictionary = effect.get_resolution_report()
        if effect.applied_this_cycle and not report.is_empty():
            last_resolution_reports.append(report.duplicate(true))
        CustomLogger.hint(self, trigger_effects, "Applied - " + str(effect), CustomLogger.LEVEL.VERBOSE)
        effect.complete_trigger_cycle()
    CustomLogger.hint(self, trigger_effects, name + " finished.", CustomLogger.LEVEL.VERBOSE)
    effects_triggered.emit(request_id)


## Returns whether effect.
func has_effect(id: String, source_id: StringName) -> bool:
    return get_effect(id, source_id) != null


## Returns effect for this effect directors.
func get_effect(id: String, source_id: StringName, across_sources: bool = false) -> EffectBase:
    for effect in get_children():
        if (
            effect is EffectBase
            and not effect.is_queued_for_deletion()
            and effect.id == id
            and (
                effect.source_id == source_id
                or (across_sources and effect.source_template and effect.source_template.stacking_across_sources)
            )
        ):
            return effect
    return null


## Returns whether effects to trigger.
func has_effects_to_trigger() -> bool:
    var has: bool = false
    for effect in get_children():
        if not effect.ticked:
            has = true
            break

    return has
#endregion
