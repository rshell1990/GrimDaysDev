extends RefCounted
## Per-cast accuracy bookkeeping shared by immediate action operations and their
## chained children. The router is weak to avoid a context/router reference cycle.
## Lifecycle grants are not retained here: their later ticks own separate timing.
class_name BattleActionHitContext

## Weak action-router reference; avoids retaining a completed cast through effects.
var _router: WeakRef
## Weak reaction-scope reference retained by set_targeting_context;
## accuracy does not route selections.
var _targeting_context: WeakRef
## Action-wide compatibility flag bypassing accuracy failures.
var _force_hit: bool = false
## Allows already-granted lifecycle damage to retain an inactive sender.
var _allow_defeated_source: bool = false
## Damage-attempt counts by actual recipient for lifecycle-grant eligibility.
var _attempts: Dictionary = {}
## Recipients with at least one successful damage roll in this scope.
var _hits: Dictionary = {}


## Keeps a weak reference to the action router and records forced-hit and defeated-source policies
## for this resolution.
func _init(
    router: BattleActionEffects, force_hit: bool, allow_defeated_source: bool = false
) -> void:
    _router = weakref(router) if router else null
    _force_hit = force_hit
    _allow_defeated_source = allow_defeated_source


## Weak to avoid the reaction dispatcher and its accuracy state owning each other.
func set_targeting_context(context: BattleDamageReactions) -> void:
    _targeting_context = weakref(context)


## One roll per damaging operation/recipient, never one roll for a whole composite.
## Non-damaging operations do not consult accuracy. An effect's always_hits flag
## bypasses misses/evasion; the older action-wide flag remains a compatibility grant.
func resolve_hit(effect: EffectBase, always_hits: bool) -> bool:
    if _router and not _router.get_ref():
        return true  # A retained effect must not reuse an already-finished cast.
    var actor := effect.sender as BattleUnit
    var target := effect.targeting as BattleUnit
    var router: BattleActionEffects = _router.get_ref() if _router else null
    if not effect.can_continue_resolution():
        return false
    if (
        not is_instance_valid(actor)
        or (not actor.is_active and not _allow_defeated_source)
        or not is_instance_valid(target)
        or not target.is_active
    ):
        return false
    _attempts[target] = int(_attempts.get(target, 0)) + 1
    var hit := always_hits or _force_hit or actor.check_if_hit(target)
    if hit:
        _hits[target] = true
        actor.last_target = target
        if router:
            # A lethal hit must install its defeat hooks before changing Health.
            await router.grant_lifecycle_effects(target)
    (
        target
        . damage_hit_resolved
        . emit(
            {
                "effect_id": effect.id,
                "instance_id": effect.get_instance_id(),
                "source_id": effect.source_id,
                "source": actor,
                "recipient": target,
                "trigger": effect.trigger,
                "hit": hit,
                "resolved_change": 0.0,
            }
        )
    )
    if not hit:
        SignalBus.dodged.emit(target)
    return hit and effect.can_continue_resolution()


## Lifecycle grants require any successful hit, or an entirely non-damaging
## action. This does not schedule after-hit procs; those run per operation.
func hit_or_non_damaging(target: BattleUnit) -> bool:
    return _hits.has(target) or not _attempts.has(target)
