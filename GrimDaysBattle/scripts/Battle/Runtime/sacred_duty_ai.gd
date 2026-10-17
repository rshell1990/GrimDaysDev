# Deterministic nun roles derived from owned grants and committed encounter history.
extends RefCounted
class_name SacredDutyAI


static func choose(unit: BattleUnit, events: Array) -> Dictionary:
    if not unit.skills or unit.has_madness() or unit.get_forced_action_effect():
        return {}
    var role := unit.template_resource.id
    if role not in [&"SisterHara", &"SisterKatherine", &"SisterAnastasia"]:
        return {}
    var plan := BattleSkillChainResolver.resolve(unit.skills.ledger, unit.skills.stat_values())
    var actions: Dictionary = {}
    for entry in plan.actions.values():
        for owned in unit.get_owned_actions():
            if owned.id == entry.action.id and unit.can_use_action(owned, true):
                actions[entry.tip] = owned
    var source := CombatActions.get_participant_source(unit)
    var allies: Array[BattleUnit] = source.get_unit_allies(unit)
    allies.append(unit)
    var foes: Array[BattleUnit] = source.get_unit_foes(unit)
    if foes.is_empty():
        return {}
    var opening := not events.any(
        func(event):
            return (
                event is BattleCombatEvent
                and event.actor == unit
                and event.type == BattleCombatEvent.TYPE.ACTION_FINISHED
            )
    )
    var ward: ActionTemplate = actions.get(&"intercession", actions.get(&"prayer_of_shelter"))
    if opening and role != &"SisterKatherine" and ward:
        var preferred: StringName = &"SisterKatherine" if role == &"SisterHara" else &"SisterHara"
        for ally in allies:
            if ally.template_resource.id == preferred and _can_ward(ally, ward, unit):
                return _choice(unit, ward, ally)
    if role == &"SisterAnastasia":
        var healing: ActionTemplate = actions.get(&"merciful_hands", actions.get(&"small_mercy"))
        if healing:
            var selected: BattleUnit
            var lowest: float = 1.0
            var rank := healing.get_rank_template(unit.get_action_rank(healing))
            var amount: float = rank.effects.all[0].amount
            for ally in allies:
                var health := ally.get_stat(CombatStats.STATS.Health)
                var fraction: float = health.Current / health.Max
                if (
                    fraction <= 0.6
                    and fraction < lowest
                    and health.Max - health.Current >= health.Max * amount
                    and _can_ward(ally, healing, unit, true)
                ):
                    selected = ally
                    lowest = fraction
            if selected:
                return _choice(unit, healing, selected)
    if ward:
        for ally in allies:
            var health := ally.get_stat(CombatStats.STATS.Health)
            if (role == &"SisterAnastasia" or health.Current < health.Max) and _can_ward(ally, ward, unit):
                return _choice(unit, ward, ally)
    if role == &"SisterKatherine" and actions.has(&"measured_penance"):
        return _choice(unit, actions[&"measured_penance"], foes[0])
    if actions.has(&"righteous_censure"):
        for foe in foes:
            if not _status(foe, &"sacred_duty_censure"):
                return _choice(unit, actions[&"righteous_censure"], foe)
    for node in [&"candlelight", &"measured_penance", &"ritual_cut"]:
        if actions.has(node):
            return _choice(unit, actions[node], foes[0])
    return _choice(unit, unit.get_basic_action(), foes[0])


# Support never downgrades an existing ward. A heal may renew an equal/stronger ward.
static func _can_ward(target: BattleUnit, action: ActionTemplate, caster: BattleUnit, healing: bool = false) -> bool:
    var missing: bool = false
    for effect in action.get_rank_template(caster.get_action_rank(action)).effects.all:
        if effect is not EffectPercentageChangeStatTemplate:
            continue
        var current := _status(target, effect.id)
        if current and current.source_template.percentage > effect.percentage + 0.00001:
            return false
        if not current:
            missing = true
    return healing or missing


static func _status(unit: BattleUnit, id: StringName) -> EffectBase:
    for holder in unit.effect_manager.triggers_to_holders.values():
        for effect in holder.get_children():
            if effect is EffectBase and effect.id == id and not effect.removed and not effect.is_queued_for_deletion():
                return effect
    return null


static func _choice(unit: BattleUnit, action: ActionTemplate, target: BattleUnit) -> Dictionary:
    if not action or not unit.can_use_action(action, true) or not CombatActions.valid_target(action, unit, target):
        return {}
    var targets: Array[BattleUnit] = [target]
    return {"action": action, "targets": targets}
