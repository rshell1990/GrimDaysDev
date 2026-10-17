extends RefCounted
## One resolution's guarded passive reactions. Authored action operations are
## never redispatched as passives, and an in-flight reaction cannot call itself.
class_name BattleDamageReactions

## Upper bound on nested reaction dispatch within one resolution scope.
const MAX_REACTION_DEPTH: int = 16
## Currently executing reaction entries used to prevent recursive reentry.
var _active: Dictionary = {}
## Primitive children are also bucket members while awaiting nested reactions.
## They must not be redispatched as though they were passive definitions.
var _operations: Dictionary = {}
## Independent accuracy bookkeeping shared by reactions in this scope.
var _hit_context := BattleActionHitContext.new(null, false)
## Weak reference to the owning action router, absent for standalone lifecycle damage.
var _router: WeakRef
## One genuine hostile selection per source/recipient pair in this resolution.
## Group expansion, DOT and retaliation do not synthesize selection notifications.
var _targeted: Dictionary = {}


## Connects a local hit context to this reaction scope and optionally retains a weak action-router
## reference.
func _init(router: BattleActionEffects = null) -> void:
    _router = weakref(router) if router else null
    _hit_context.set_targeting_context(self)


## Emits hostile selection and awaits TARGETED reactions once per source/recipient pair. Marks the
## pair before callbacks to prevent counter recursion; skips inactive, friendly or cancelled
## selections.
func ensure_targeted(source: BattleUnit, recipient: BattleUnit, continuation: Callable) -> void:
    if (
        not _allowed(continuation)
        or not is_instance_valid(source)
        or not is_instance_valid(recipient)
        or not source.is_active
        or not recipient.is_active
        or source == recipient
    ):
        return
    var same_team := source.get_parent() == recipient.get_parent()
    if not source.team_id.is_empty() and not recipient.team_id.is_empty():
        same_team = source.team_id == recipient.team_id
    if same_team:
        return
    var key := "%s:%s" % [source.get_instance_id(), recipient.get_instance_id()]
    if _targeted.has(key):
        return
    _targeted[key] = true  # Mark before callbacks/counters can reenter.
    recipient.action_targeted.emit(
        {"source": source, "recipient": recipient, "trigger": CombatEffects.TRIGGER.TARGETED, "resolved_change": 0.0}
    )
    var router: BattleActionEffects = _router.get_ref() if _router else null
    await _dispatch(
        recipient,
        CombatEffects.TRIGGER.TARGETED,
        source,
        continuation,
        {"action_actor": source, "action_defender": recipient, "action_context": router.execution if router else null}
    )


## A primitive is already in its trigger bucket while targeting reactions run.
## Protect it throughout accuracy too, not only while awaiting damage reactions.
func resolve_hit(effect: EffectBase, hit_context: BattleActionHitContext, always_hits: bool) -> bool:
    var instance_id := effect.get_instance_id()
    _operations[instance_id] = true
    var hit := await hit_context.resolve_hit(effect, always_hits)
    _operations.erase(instance_id)
    return hit


## Successful accuracy opens defense and attacker hit-proc windows before magnitude calculation.
func before_damage(effect: EffectBase) -> bool:
    var instance_id := effect.get_instance_id()
    _operations[instance_id] = true
    var roles: Dictionary = effect.get_meta(EffectBase.CHAIN_CONTEXT_META, {})
    await _dispatch(
        effect.targeting, CombatEffects.TRIGGER.BEFORE_DAMAGE, effect.sender, effect.can_continue_resolution, roles
    )
    var is_action_hit: bool = (
        not roles.has("action_actor")
        or (effect.sender == roles.action_actor and effect.targeting == roles.get("action_defender"))
    )
    if _can_damage(effect) and is_action_hit:
        await _dispatch(
            effect.sender, CombatEffects.TRIGGER.AFTER_HITTING, effect.targeting, effect.can_continue_resolution, roles
        )
        var router: BattleActionEffects = _router.get_ref() if _router else null
        if router and _can_damage(effect):
            await router.resolve_after_hit(effect)
    _operations.erase(instance_id)
    return _can_damage(effect)


## Health is already updated. Only the enclosing action's defender opens DAMAGED;
## a reflected effect retains its source without exchanging attacker/defender roles.
func after_damage(effect: EffectBase) -> void:
    var instance_id := effect.get_instance_id()
    _operations[instance_id] = true
    var roles: Dictionary = effect.get_meta(EffectBase.CHAIN_CONTEXT_META, {})
    if not roles.has("action_defender") or effect.targeting == roles.action_defender:
        await _dispatch(
            effect.targeting, CombatEffects.TRIGGER.DAMAGED, effect.sender, effect.can_continue_resolution, roles, true
        )
    await BattleEncounterEffects.resolve_unit_defeat(effect.targeting, effect.can_continue_resolution, roles)
    _operations.erase(instance_id)


## Checks continuation and recipient activity, allowing an inactive sender only when the scoped
## effect context explicitly permits posthumous damage.
func _can_damage(effect: EffectBase) -> bool:
    var context: Dictionary = effect.get_meta(EffectBase.CHAIN_CONTEXT_META, {})
    return (
        effect.can_continue_resolution()
        and is_instance_valid(effect.sender)
        and effect.sender is BattleUnit
        and (effect.sender.is_active or context.get("allow_defeated_source", false))
        and is_instance_valid(effect.targeting)
        and effect.targeting is BattleUnit
        and effect.targeting.is_active
    )


## Snapshot a bucket once, excluding authored operations and visited instances.
## Use local completion state rather than nesting the director's shared report
## buffer. Primitive event capture observes every actual operation directly.
func _dispatch(
    owner: BattleUnit,
    trigger: CombatEffects.TRIGGER,
    other: BattleUnit,
    continuation: Callable,
    roles: Dictionary = {},
    allow_inactive: bool = false
) -> void:
    if (
        not is_instance_valid(owner)
        or (not owner.is_active and not allow_inactive)
        or _active.size() >= MAX_REACTION_DEPTH
    ):
        return
    var holder: EffectDirectors = owner.effect_manager.triggers_to_holders.get(trigger)
    if not holder:
        return
    # A reaction can free a later snapshot entry while this dispatch awaits.
    # Validate the Variant before assigning it to a typed object variable.
    for entry: Variant in holder.get_children():
        if not _allowed(continuation) or not is_instance_valid(owner) or (not owner.is_active and not allow_inactive):
            break
        if not is_instance_valid(entry) or not entry is EffectBase:
            continue
        var effect: EffectBase = entry
        if effect.removed or effect.is_queued_for_deletion():
            continue
        var instance_id := effect.get_instance_id()
        var original: Dictionary = effect.get_meta(EffectBase.CHAIN_CONTEXT_META, {})
        if original.get("action_operation", false) or _active.has(instance_id) or _operations.has(instance_id):
            continue
        var context := original.duplicate(true)
        for key in ["action_actor", "action_defender", "action_context"]:
            if roles.has(key):
                context[key] = roles[key]
        context["damage_reactions"] = self
        context["action_hit_context"] = _hit_context
        context["reaction_target"] = other
        context["reaction_trigger"] = trigger
        context["allow_defeated_source"] = false  # A new counter still requires a living reactor.
        context["continuation"] = continuation
        var old_guard := effect.resolution_continuation
        _active[instance_id] = true
        effect.set_chain_context(context)
        effect.resolve_application()
        while (
            is_instance_valid(effect)
            and not effect.is_queued_for_deletion()
            and (not effect.finished or effect.resolving_application)
            and _allowed(continuation)
        ):
            await owner.get_tree().process_frame
        if is_instance_valid(effect):
            effect.complete_trigger_cycle()
            effect.set_chain_context(original)
            effect.resolution_continuation = old_guard
        _active.erase(instance_id)


## Accepts an absent continuation; otherwise requires a valid callable that still authorizes
## resolution.
func _allowed(continuation: Callable) -> bool:
    return continuation.is_null() or (continuation.is_valid() and continuation.call())
