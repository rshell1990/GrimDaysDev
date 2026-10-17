# Encounter-local choices derived from committed history, so retries need no extra AI state.
extends RefCounted
class_name StreetBulliesAI


static func choose(unit: BattleUnit, events: Array) -> Dictionary:
    if not unit.skills or unit.has_madness() or unit.get_forced_action_effect():
        return {}
    var role := unit.template_resource.id
    if role not in [&"HarlokTeen", &"GoonATeen", &"GoonBTeen"]:
        return {}
    var plan := BattleSkillChainResolver.resolve(unit.skills.ledger, unit.skills.stat_values())
    var actions: Dictionary = {}
    for entry in plan.actions.values():
        for owned in unit.get_owned_actions():
            if owned.id == entry.action.id and unit.can_use_action(owned, true):
                actions[entry.tip] = owned
    if plan.actions.is_empty():
        return {}
    var history: Array[ActionTemplate] = []
    for event in events:
        if (
            event is BattleCombatEvent
            and event.actor == unit
            and event.type == BattleCombatEvent.TYPE.ACTION_FINISHED
            and event.action
        ):
            history.append(event.action)
    var source := CombatActions.get_participant_source(unit)
    var allies: Array[BattleUnit] = source.get_unit_allies(unit)
    var foes: Array[BattleUnit] = source.get_unit_foes(unit)
    if foes.is_empty():
        return {}
    if role == &"HarlokTeen":
        if history.is_empty() and actions.has(&"get_em") and not allies.is_empty():
            var mate: BattleUnit = allies[0]
            for ally in allies:
                if ally.template_resource.id == &"GoonATeen":
                    mate = ally
                    break
            return _choice(unit, actions.get(&"get_em"), mate)
    elif role == &"GoonATeen":
        if actions.has(&"big_talk") and not _used(history, actions[&"big_talk"]):
            return _choice(unit, actions[&"big_talk"], unit)
    else:
        var dirt: ActionTemplate = actions.get(&"kick_dirt")
        if dirt and (history.is_empty() or history.back().id != dirt.id):
            for foe in foes:
                if not _has_status(foe, &"street_bullies_grit_in_the_eyes"):
                    return _choice(unit, dirt, foe)
        # Boasting follows the opening and only happens while both mates remain present.
        if (
            not history.is_empty()
            and allies.size() >= 2
            and actions.has(&"big_talk")
            and not _used(history, actions[&"big_talk"])
        ):
            return _choice(unit, actions[&"big_talk"], unit)
    for node in [&"shoulder_check", &"follow_up_elbow", &"cheap_shot"]:
        if actions.has(node):
            return _choice(unit, actions[node], foes[0])
    return _choice(unit, unit.get_basic_action(), foes[0])


static func _used(history: Array[ActionTemplate], action: ActionTemplate) -> bool:
    return history.any(func(previous: ActionTemplate): return previous.id == action.id)


static func _has_status(unit: BattleUnit, id: StringName) -> bool:
    for holder in unit.effect_manager.triggers_to_holders.values():
        for effect in holder.get_children():
            if effect is EffectBase and effect.id == id and not effect.removed and not effect.is_queued_for_deletion():
                return true
    return false


static func _choice(unit: BattleUnit, action: ActionTemplate, target: BattleUnit) -> Dictionary:
    if not action or not unit.can_use_action(action, true) or not CombatActions.valid_target(action, unit, target):
        return {}
    return {"action": action, "targets": [target]}
