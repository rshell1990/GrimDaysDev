extends EffectBase
## Implements the runtime effect scaled stat change behavior used by the battle effect pipeline.
class_name EffectScaledStatChange

## Preloaded dependency used to construct or identify the damage rules.
const DAMAGE_RULES := preload("res://GrimDaysBattle/scripts/_Global/combat_damage_resolver.gd")

## Runtime effect template state used by this effect scaled stat change.
var effect_template: EffectScalingCombatStatChangeTemplate
## Runtime raw change state used by this effect scaled stat change.
var raw_change: float
## Runtime resolved change state used by this effect scaled stat change.
var resolved_change: float
## Runtime mitigation percent state used by this effect scaled stat change.
var mitigation_percent: float
## Whether the critical hit condition currently holds.
var critical_hit: bool
## Per-instance frozen operation, including its initial damage roll and mitigation.
var snapshot_ready: bool = false
var snapshot_raw_change: float
var snapshot_change: float
var snapshot_critical: bool = false
var snapshot_mitigation: float = 0.0


## Initializes this effect scaled stat change from the supplied runtime dependencies.
func setup(sent_by: Variant, target_node: Variant, template: Variant) -> void:
    super(sent_by, target_node, template)
    effect_template = template
    if effect_template.snapshots_amount():
        _capture_snapshot()


## Applies this effect scaled stat change's configured behavior to its current target.
func apply() -> void:
    if not _begin_apply():
        return
    raw_change = 0.0
    resolved_change = 0.0
    mitigation_percent = 0.0
    critical_hit = false
    if not effect_template:
        _finish_with_error("Scaled stat effect %s has no valid template." % id)
        return
    if targeting is not BattleUnit:
        _finish_with_error("Scaled stat effect %s requires a BattleUnit target." % id)
        return

    var target_unit: BattleUnit = targeting
    var scaling_stat: UnitGenericStat
    var scaler: BattleUnit
    if not snapshot_ready:
        scaler = sender as BattleUnit if effect_template.scales_from_sender else target_unit
        if not scaler:
            _finish_with_error("Scaled stat effect %s has no BattleUnit scaler." % id)
            return

        scaling_stat = scaler.get_stat(effect_template.scales_with)
        if not scaling_stat:
            _finish_with_error(
                (
                    "Effect %s could not find scaling stat %s on %s."
                    % [id, CombatStats.get_stat_as_string(effect_template.scales_with), scaler.name]
                )
            )
            return
    var changed_stat := target_unit.get_stat(effect_template.stat)
    if not changed_stat:
        _finish_with_error(
            (
                "Effect %s could not find target stat %s on %s."
                % [id, CombatStats.get_stat_as_string(effect_template.stat), target_unit.name]
            )
        )
        return

    if effect_template.snapshots_amount() and not snapshot_ready:
        _finish_with_error("Timed scaled effect %s has no valid attachment snapshot." % id)
        return
    var damaging := snapshot_raw_change < 0.0 if snapshot_ready else effect_template.scales_by < 0.0
    if damaging:
        if effect_template.damage_type == CombatDamage.TYPE.None:
            _finish_with_error("Damaging effect %s must declare Physical, Magic, or True damage." % id)
            return
        if not await _action_damage_hits(effect_template.always_hits):
            _finish_apply()
            return
        if effect_template.stat == CombatStats.STATS.Health and not await _before_action_damage():
            _finish_apply()
            return
        raw_change = snapshot_raw_change if snapshot_ready else scaling_stat.Current * effect_template.scales_by
        if not snapshot_ready and effect_template.scales_with_damage:
            var damage_modifier := scaler.get_stat(CombatStats.STATS.DamageModifier)
            if not damage_modifier:
                _finish_with_error("Effect %s requires a DamageModifier stat." % id)
                return
            raw_change *= damage_modifier.Current

        _apply_damage(target_unit, changed_stat, absf(raw_change), sender as BattleUnit)
        if effect_template.stat == CombatStats.STATS.Health:
            await _after_action_damage()
        await _apply_strike_followups(effect_template, critical_hit)
    else:
        raw_change = snapshot_raw_change if snapshot_ready else scaling_stat.Current * effect_template.scales_by
        if not snapshot_ready and effect_template.scales_with_damage:
            var damage_modifier := scaler.get_stat(CombatStats.STATS.DamageModifier)
            if not damage_modifier:
                _finish_with_error("Effect %s requires a DamageModifier stat." % id)
                return
            raw_change *= damage_modifier.Current

        _apply_restoration(target_unit, changed_stat, snapshot_change if snapshot_ready else raw_change)
    _finish_apply()


## Describes the resolved stat operation for deterministic combat-event capture.
func get_resolution_report() -> Dictionary:
    if not applied_this_cycle or not effect_template:
        return {}
    return {
        "effect_id": id,
        "stat": effect_template.stat,
        "raw_change": raw_change,
        "resolved_change": resolved_change,
        "critical": critical_hit,
        "damage_type": effect_template.damage_type,
    }


## Applies damage for this effect scaled stat change.
func _apply_damage(
    target_unit: BattleUnit,
    changed_stat: UnitGenericStat,
    damage: float,
    attacker: BattleUnit,
) -> void:
    if snapshot_ready:
        critical_hit = snapshot_critical
        mitigation_percent = snapshot_mitigation
        resolved_change = absf(snapshot_change)
    else:
        var roll := _evaluate_damage(damage, target_unit, attacker)
        critical_hit = roll.critical
        mitigation_percent = roll.mitigation
        resolved_change = roll.amount
    if critical_hit:
        SignalBus.preformed_crit.emit(attacker)
        SignalBus.received_crit.emit(target_unit)
    var old_value := changed_stat.Current
    changed_stat.decrease_current_flat(resolved_change)
    resolved_change = old_value - changed_stat.Current
    _record_resource_operation(
        changed_stat, old_value, raw_change, critical_hit, effect_template.damage_type, mitigation_percent
    )
    if resolved_change <= 0.0:
        return
    if effect_template.stat == CombatStats.STATS.Health:
        # Scaling from the victim's stats does not make the victim the attacker.
        # Defeated sources remain roster members until encounter cleanup, so DOT
        # keeps its originating unit even after that unit can no longer act.
        target_unit.last_hit_by = attacker
        SignalBus.damaged.emit(target_unit, roundi(resolved_change))


## Applies restoration for this effect scaled stat change.
func _apply_restoration(
    target_unit: BattleUnit,
    changed_stat: UnitGenericStat,
    amount: float,
) -> void:
    var old_value := changed_stat.Current
    changed_stat.increase_current_flat(amount)
    resolved_change = changed_stat.Current - old_value
    _record_resource_operation(changed_stat, old_value, amount)
    if resolved_change > 0.0 and effect_template.stat == CombatStats.STATS.Health:
        SignalBus.healed.emit(target_unit, roundi(resolved_change))


## Rolls critical for this effect scaled stat change.
func _roll_critical(scaler: BattleUnit) -> bool:
    if not is_instance_valid(scaler) or not effect_template.can_critical:
        return false
    var critical_stat := scaler.get_stat(CombatStats.STATS.CriticalStrike)
    if not critical_stat or critical_stat.Current + effect_template.critical_chance_bonus <= 0.0:
        return false
    if not scaler.randomizer:
        return false
    if effect_template.critical_chance_bonus == 0.0:
        return scaler.check_if_crit()
    return scaler.randomizer.roll(critical_stat.Current + effect_template.critical_chance_bonus)


## Finishes with error for this effect scaled stat change.
func _finish_with_error(message: String) -> void:
    push_error(message)
    _finish_apply()


## Samples once for a snapshot, or once per application for ordinary live-scaled damage.
func _evaluate_damage(amount: float, recipient: BattleUnit, attacker: BattleUnit) -> Dictionary:
    if effect_template.damage_type in [CombatDamage.TYPE.Physical, CombatDamage.TYPE.Magic]:
        var roll_owner := attacker if is_instance_valid(attacker) else recipient
        var randomizer := roll_owner.get_node("Randomizer") as UnitRandomizationControl
        amount *= DAMAGE_RULES.roll_variance(effect_template.damage_type, randomizer.random_number_generator)
    var critical := _roll_critical(attacker)
    if critical:
        amount *= maxf(effect_template.critical_damage_multiplier, 0.0)
    var mitigation: float = 0.0
    var resistance_id := DAMAGE_RULES.get_resistance_stat(effect_template.damage_type)
    if not effect_template.bypass_mitigation and resistance_id != CombatStats.STATS.Empty:
        var resistance := recipient.get_stat(resistance_id)
        if resistance:
            mitigation = resistance.Current
    return {
        "amount": DAMAGE_RULES.resolve_damage(amount, effect_template.damage_type, mitigation),
        "critical": critical,
        "mitigation": mitigation
    }


func _capture_snapshot() -> void:
    var recipient := targeting as BattleUnit
    var scaler := sender as BattleUnit if effect_template.scales_from_sender else recipient
    if not is_instance_valid(recipient) or not is_instance_valid(scaler):
        return
    var stat := scaler.get_stat(effect_template.scales_with)
    if not stat:
        return
    snapshot_raw_change = stat.Current * effect_template.scales_by
    if effect_template.scales_with_damage:
        var modifier := scaler.get_stat(CombatStats.STATS.DamageModifier)
        if not modifier:
            return
        snapshot_raw_change *= modifier.Current
    snapshot_change = snapshot_raw_change
    if snapshot_change < 0:
        var roll := _evaluate_damage(absf(snapshot_change), recipient, sender as BattleUnit)
        snapshot_change = -float(roll.amount)
        snapshot_critical = roll.critical
        snapshot_mitigation = roll.mitigation
    snapshot_ready = true


## The authored text remains unchanged; x is the frozen magnitude for this runtime stack.
func get_description() -> String:
    return effect_template.get_description(absf(snapshot_change)) if snapshot_ready else super()
