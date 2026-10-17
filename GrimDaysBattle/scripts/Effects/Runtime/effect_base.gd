extends Node
#region EFFECT BASE
## Runtime instance of an authored effect. Lifetime determines removal while kind
## and trigger determine what the effect does and when it executes.
## Effects may change combat state or request presentation such as animations,
## particles, sounds, and sprite changes.
class_name EffectBase
#endregion

## Emitted when applied.
signal applied

#region VARIABLES
## The string name id of this effect.
var id: StringName
## Authored definition retained for runtime descriptions without mutating shared Resources.
var source_template: EffectTemplate
## The original sender of this effect.
var sender: Node
## Stable owner of the grant, independent from the sender node's instance ID.
var source_id: StringName
## The valid targets for this effect.
var target: CombatActions.TARGET
## The target of this effect.
var targeting: Node
## The current number of combat rounds left until this effect expires.
var duration: int
## The starting number of combat rounds until this effect expires.
var max_duration: int
## Follow-up definitions copied at setup; only natural round expiry grants them.
var effects_on_expiry: Array[EffectTemplate] = []
## Duplicate policy retained by the existing runtime instance.
var stacking: EffectTemplate.STACKING = EffectTemplate.STACKING.REFRESH
## Whether the effect is a one-shot, repeating behavior, buff, or debuff.
var kind: CombatEffects.KIND
## Event category that invokes this effect.
var trigger: CombatEffects.TRIGGER
## Removal policy copied from the effect definition.
var lifetime: EffectTemplate.LIFETIME = EffectTemplate.LIFETIME.INSTANT
## Whether this effect has ticked recently.
var ticked: bool
## Whether this effect is finished.
var finished: bool
## Whether the most recent apply request actually executed. Directors use this
## to ensure repeated trigger requests cannot consume duration twice.
var applied_this_cycle: bool
## Whether the removed condition currently holds.
var removed: bool
## Scoped to the current trigger, inherited by nested operations. Lifetime
## grants must receive the next trigger's guard, not retain an old action guard.
var resolution_continuation: Callable
## Deadline owned by this primitive while its nested reactions run.
var _animation_delay_deadline: int = 0
## Directors poll this separately so removal can wake them during a carried delay.
var resolving_application: bool = false
## Keeps a cancelled await cancelled after a director restores its outer context.
var _application_guard: Callable
#endregion

## Fixed chain context meta value shared by all effect base instances.
const CHAIN_CONTEXT_META: StringName = &"effect_chain_context"


## Initializes tree-dependent state as this node enters the scene tree.
func _enter_tree() -> void:
    var parent = get_parent()
    parent.set_meta(name, self)
    (
        CustomLogger
        . hint(
            self,
            _enter_tree,
            "Entered tree. Owner: %s" % get_parent().get_parent().get_parent(),
            CustomLogger.LEVEL.VERY_VERBOSE,
        )
    )


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    SignalBus.tick.connect(on_round_boundary)


#region MAIN


## Returns attached for this effect base.
func get_attached() -> Node:
    return get_parent().get_attached() if get_parent().has_method("get_attached") else get_parent()


## Consumes one round of lifetime and grants follow-ups on natural expiry.
func tick() -> void:
    if removed or is_queued_for_deletion() or lifetime != EffectTemplate.LIFETIME.ROUNDS:
        return
    CustomLogger.hint(self, tick, "Ticking round lifetime.", CustomLogger.LEVEL.VERY_VERBOSE)
    duration -= 1
    if duration < 1:
        CustomLogger.confirm(self, tick, "Effect expired and will be freed.", CustomLogger.LEVEL.VERBOSE)
        _expire()


## Revoke first, then grant independently owned follow-ups to the actual holder.
func _expire() -> void:
    if effects_on_expiry.is_empty() or not is_inside_tree():
        remove()
        return
    var recipient := get_attached() as BattleUnit
    remove()
    if not is_instance_valid(recipient) or recipient.is_queued_for_deletion():
        return
    var origin: Node = sender if is_instance_valid(sender) else recipient
    for definition in effects_on_expiry:
        if not definition:
            continue
        (
            recipient
            . effect_manager
            . grant_expiry_effect(
                origin,
                definition,
                {
                    "source_id": StringName("expiry:%s:%s" % [source_id, id]),
                    "expiry_recipient": recipient,
                }
            )
        )


## Handles the round boundary notification for this effect base.
func on_round_boundary(_request_id: StringName) -> void:
    # Trigger eligibility and lifetime are independent. Reset first so a
    # ROUND_OVER effect can be eligible on the next round if it survives.
    ticked = false
    finished = false
    applied_this_cycle = false
    tick()


## Initializes this effect base from the supplied runtime dependencies.
func setup(sent_by: Variant, target_node: Variant, template: Variant) -> void:
    source_template = template
    id = template.id
    sender = sent_by
    source_id = StringName("runtime_source:%s" % sent_by.get_instance_id()) if sent_by else id
    target = template.target
    targeting = target_node
    duration = template.duration
    max_duration = template.duration
    stacking = template.stacking
    kind = template.kind
    trigger = template.trigger
    lifetime = template.lifetime
    effects_on_expiry.assign(template.effects_on_expiry)


## Sets chain context for this effect base.
func set_chain_context(context: Dictionary) -> void:
    set_meta(CHAIN_CONTEXT_META, context.duplicate(true))
    resolution_continuation = context.get("continuation", Callable())
    if context.has("source_id"):
        source_id = StringName(context.source_id)


#endregion


#region OVERRIDE FUNCTIONS
## The logic to be defined as to what the effect actually does when applied.
func apply() -> void:
    if not _begin_apply():
        return
    _finish_apply()


## Starts one application attempt. Derived effects must return immediately when
## this returns false, preventing instant effects from applying twice.
func _begin_apply() -> bool:
    if not resolving_application:
        _application_guard = Callable()
    if not can_continue_resolution():
        applied_this_cycle = false
        _finish_apply()
        return false
    if ticked:
        applied_this_cycle = false
        finished = true
        return false
    ticked = true
    finished = false
    applied_this_cycle = true
    return true


## Returns whether this effect has not been removed or scheduled for deletion and may keep running.
## If a continuation function was supplied, calls it to check that the battle still allows the
## effect to continue.
func can_continue_resolution() -> bool:
    return (
        not removed
        and not is_queued_for_deletion()
        and (_application_guard.is_null() or (_application_guard.is_valid() and _application_guard.call()))
        and (
            resolution_continuation.is_null() or (resolution_continuation.is_valid() and resolution_continuation.call())
        )
    )


## Completes an application exactly once so directors cannot wait forever.
func _finish_apply() -> void:
    if finished:
        return
    finished = true
    applied.emit()


## Handles remove for this effect base.
func remove() -> void:
    if removed:
        return
    removed = true
    _revoke()
    queue_free()


## Called by a director after one trigger request has fully resolved.
func complete_trigger_cycle() -> void:
    if lifetime == EffectTemplate.LIFETIME.INSTANT:
        remove()
    elif kind == CombatEffects.KIND.REPEAT and trigger != CombatEffects.TRIGGER.ROUND_OVER:
        # Event-driven repeats become eligible for the next distinct event. A
        # ROUND_OVER repeat waits for the round boundary so duplicate resolution
        # requests cannot apply it more than once for the same round.
        ticked = false
        finished = false
        applied_this_cycle = false


## Publishes one primitive resource mutation, including nested chain children.
## Report at the mutation site, not at director completion: a chain may contain
## multiple operations whose net change would otherwise hide damage or healing.
func _record_resource_operation(
    stat: UnitGenericStat,
    before: float,
    raw_amount: float,
    critical: bool = false,
    damage_type: int = CombatDamage.TYPE.None,
    mitigation: float = 0.0
) -> void:
    if not is_instance_valid(targeting) or targeting is not BattleUnit:
        return
    if stat.id == CombatStats.STATS.Health and (before > 0 or stat.Current > 0):
        targeting.defeat_resolved = false
        targeting.kill_resolved = false
    (
        targeting
        . resource_operation_resolved
        . emit(
            {
                "effect_id": id,
                "instance_id": get_instance_id(),
                "source_id": source_id,
                "source": sender as BattleUnit,
                "recipient": targeting,
                "stat": stat.id,
                "trigger": trigger,
                "before": before,
                "after": stat.Current,
                "raw_change": raw_amount,
                "resolved_change": absf(stat.Current - before),
                "critical": critical,
                "damage_type": damage_type,
                "mitigation_percent": mitigation,
                "lifecycle": get_meta(CHAIN_CONTEXT_META, {}).get("lifecycle", false),
            }
        )
    )


## Scoped action accuracy; standalone/lifecycle effects keep their existing
## dispatch contract until their reaction/tick integration is migrated separately.
func _action_damage_hits(always_hits: bool) -> bool:
    var context: Dictionary = get_meta(CHAIN_CONTEXT_META, {})
    var hit_context: BattleActionHitContext = context.get("action_hit_context")
    var reactions: BattleDamageReactions = context.get("damage_reactions")
    if hit_context and reactions:
        return await reactions.resolve_hit(self, hit_context, always_hits)
    return await hit_context.resolve_hit(self, always_hits) if hit_context else true


## Await incoming reactions before reading resistance or mutating Health. The
## action's authored DAMAGED operations are excluded from this passive dispatch.
func _before_action_damage() -> bool:
    var reactions: BattleDamageReactions = get_meta(CHAIN_CONTEXT_META, {}).get("damage_reactions")
    return await reactions.before_damage(self) if reactions else can_continue_resolution()


## Awaits post-damage reactions from the current chain context when a reaction scope is present.
func _after_action_damage() -> void:
    await _finish_animation_delay()
    var reactions: BattleDamageReactions = get_meta(CHAIN_CONTEXT_META, {}).get("damage_reactions")
    if reactions:
        await reactions.after_damage(self)


## Legacy director summary of the most recent application. Primitive resource
## events use _record_resource_operation instead, so nested results are not lost.
func get_resolution_report() -> Dictionary:
    return {}


## Reverses grants owned by this effect before deferred node deletion. Stateful
## effects override this so battle cleanup is reflected in result snapshots.
func _revoke() -> void:
    pass


## Runtime-only checkpoint of script state. Do not serialize this to disk:
## sender, target and stat references deliberately retain permanent identities.
func capture_retry_state() -> Dictionary:
    var state: Dictionary = {}
    for property in get_property_list():
        if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
            var value: Variant = get(property.name)
            state[property.name] = value.duplicate(true) if value is Dictionary or value is Array else value
    return state


## Restores the effect's remembered values. Copies lists and dictionaries so later changes do not
## alter the saved retry state.
func restore_retry_state(state: Dictionary) -> void:
    for key in state:
        var value: Variant = state[key]
        set(key, value.duplicate(true) if value is Dictionary or value is Array else value)


#endregion


## Strike-local follow-ups retain the actual recipient and the action's guards/accuracy context.
## Use the chain's depth/path protection so recursively authored hit effects cannot loop forever.
func _apply_strike_followups(definition: EffectTemplate, critical: bool) -> void:
    var definitions: Array[EffectTemplate] = []
    definitions.append_array(definition.effects_on_hit)
    if critical:
        definitions.append_array(definition.effects_on_critical)
    if (
        definitions.is_empty()
        or not can_continue_resolution()
        or targeting is not BattleUnit
        or not targeting.is_active
    ):
        return
    var sequence := EffectTriggerAnotherEffect.new()
    sequence.id = StringName("%s:strike_followups" % id)
    sequence.triggers = definitions
    var chain := EffectTriggerChain.new()
    chain.name = StringName("strike_followups_%s" % chain.get_instance_id())
    chain.setup(sender, targeting, sequence)
    var context: Dictionary = get_meta(CHAIN_CONTEXT_META, {}).duplicate(true)
    var path: Array = context.get("path", []).duplicate()
    if id not in path:
        path.append(id)
    context["path"] = path
    context["depth"] = int(context.get("depth", 0)) + 1
    context["source_id"] = source_id
    context["continuation"] = can_continue_resolution
    context["after_hit_operation"] = true
    context["strike_followup"] = true
    context["reaction_target"] = targeting
    chain.set_chain_context(context)
    add_child(chain)
    await chain.apply()
    if is_instance_valid(chain):
        chain.remove()


## Instance-aware description entry point for status displays.
func get_description() -> String:
    return source_template.get_description() if source_template else ""


## Resolves one primitive and its inherited animation tail. Chains pass timing to children.
func resolve_application() -> void:
    resolving_application = true
    _application_guard = resolution_continuation
    var timing: BattleActionContext = get_meta(CHAIN_CONTEXT_META, {}).get("action_context")
    _animation_delay_deadline = 0
    if timing and not self is EffectTriggerChain:
        _animation_delay_deadline = timing.take_animation_delay()
    apply()
    while not is_queued_for_deletion() and not finished and can_continue_resolution():
        await get_tree().process_frame
    await _finish_animation_delay()
    resolving_application = false


## Damage feedback is already emitted; finish its tail before post-damage follow-ups.
func _finish_animation_delay() -> void:
    var timing: BattleActionContext = get_meta(CHAIN_CONTEXT_META, {}).get("action_context")
    var deadline := _animation_delay_deadline
    _animation_delay_deadline = 0
    if timing and can_continue_resolution():
        await timing.wait_until(self, deadline, can_continue_resolution)
