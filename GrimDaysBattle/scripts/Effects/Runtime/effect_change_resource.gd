extends EffectBase
## Implements the runtime effect change resource behavior used by the battle effect pipeline.
class_name EffectChangeResource

## Preloaded dependency used to construct or identify the damage rules.
const DAMAGE_RULES := preload("res://GrimDaysBattle/scripts/_Global/combat_damage_resolver.gd")
## Preloaded dependency used to construct or identify the resource template script.
const RESOURCE_TEMPLATE_SCRIPT := preload(
    "res://GrimDaysBattle/scripts/Effects/Resources/effect_change_resource.gd"
)

## Runtime effect template state used by this effect change resource.
var effect_template
## Runtime raw change state used by this effect change resource.
var raw_change: float
## Runtime resolved change state used by this effect change resource.
var resolved_change: float
## Runtime mitigation percent state used by this effect change resource.
var mitigation_percent: float


## Initializes this effect change resource from the supplied runtime dependencies.
func setup(sent_by: Variant, target_node: Variant, template: Variant) -> void:
    super(sent_by, target_node, template)
    effect_template = template


## Applies this effect change resource's configured behavior to its current target.
func apply() -> void:
    if not _begin_apply():
        return
    raw_change = 0.0
    resolved_change = 0.0
    mitigation_percent = 0.0
    if not effect_template or targeting is not BattleUnit:
        _finish_with_error("Resource effect %s requires a valid template and BattleUnit target." % id)
        return
    var target_unit: BattleUnit = targeting
    var resource := target_unit.get_stat(effect_template.stat)
    if not resource:
        _finish_with_error(
            (
                "Resource effect %s could not find %s on %s."
                % [id, CombatStats.get_stat_as_string(effect_template.stat), target_unit.name]
            )
        )
        return

    if effect_template.amount < 0.0:
        if effect_template.stat == CombatStats.STATS.Health and effect_template.damage_type == CombatDamage.TYPE.None:
            _finish_with_error("Health damage effect %s must declare a damage type." % id)
            return
        if (
            effect_template.stat == CombatStats.STATS.Health
            and not await _action_damage_hits(effect_template.always_hits)
        ):
            _finish_apply()
            return
        if effect_template.stat == CombatStats.STATS.Health and not await _before_action_damage():
            _finish_apply()
            return
        raw_change = _calculate_change(resource)
        _apply_decrease(target_unit, resource, absf(raw_change))
        if effect_template.stat == CombatStats.STATS.Health:
            await _after_action_damage()
        await _apply_strike_followups(effect_template, false)
    else:
        raw_change = _calculate_change(resource)
        _apply_restoration(target_unit, resource, raw_change)
    _finish_apply()


## Calculates change for this effect change resource.
func _calculate_change(resource: UnitGenericStat) -> float:
    match effect_template.amount_mode:
        RESOURCE_TEMPLATE_SCRIPT.AMOUNT_MODE.PERCENT_CURRENT:
            return resource.Current * effect_template.amount
        RESOURCE_TEMPLATE_SCRIPT.AMOUNT_MODE.PERCENT_MAX:
            return resource.Max * effect_template.amount
        _:
            return effect_template.amount


## Applies decrease for this effect change resource.
func _apply_decrease(target_unit: BattleUnit, resource: UnitGenericStat, amount: float) -> void:
    var resolved_amount := amount
    if effect_template.stat == CombatStats.STATS.Health:
        if effect_template.damage_type == CombatDamage.TYPE.None:
            _finish_with_error("Health damage effect %s must declare a damage type." % id)
            return
        var resistance_id := DAMAGE_RULES.get_resistance_stat(effect_template.damage_type)
        mitigation_percent = 0.0
        if not effect_template.bypass_mitigation and resistance_id != CombatStats.STATS.Empty:
            var resistance := target_unit.get_stat(resistance_id)
            if resistance:
                mitigation_percent = resistance.Current
        var varied_amount := amount
        if effect_template.damage_type in [CombatDamage.TYPE.Physical, CombatDamage.TYPE.Magic]:
            var roll_owner: BattleUnit = sender if is_instance_valid(sender) and sender is BattleUnit else target_unit
            # Equipment effects can run before the unit caches its child services.
            var randomizer := roll_owner.get_node("Randomizer") as UnitRandomizationControl
            varied_amount *= DAMAGE_RULES.roll_variance(effect_template.damage_type, randomizer.random_number_generator)
        resolved_amount = DAMAGE_RULES.resolve_damage(varied_amount, effect_template.damage_type, mitigation_percent)
    var old_value := resource.Current
    resource.decrease_current_flat(resolved_amount)
    resolved_change = old_value - resource.Current
    _record_resource_operation(resource, old_value, -amount, false, effect_template.damage_type, mitigation_percent)
    if effect_template.stat == CombatStats.STATS.Health and resolved_change > 0.0:
        if sender is BattleUnit:
            target_unit.last_hit_by = sender
        SignalBus.damaged.emit(target_unit, roundi(resolved_change))


## Applies restoration for this effect change resource.
func _apply_restoration(target_unit: BattleUnit, resource: UnitGenericStat, amount: float) -> void:
    var old_value := resource.Current
    resource.increase_current_flat(amount)
    resolved_change = resource.Current - old_value
    _record_resource_operation(resource, old_value, amount)
    if effect_template.stat == CombatStats.STATS.Health and resolved_change > 0.0:
        SignalBus.healed.emit(target_unit, roundi(resolved_change))


## Finishes with error for this effect change resource.
func _finish_with_error(message: String) -> void:
    CustomLogger.error(self, apply, message, CustomLogger.LEVEL.IMPORTANT)
    _finish_apply()
