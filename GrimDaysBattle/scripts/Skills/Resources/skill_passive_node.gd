# Editor configuration for BattleSkillPassiveNode.
@tool
extends BattleSkillNode
## Reversible passive payload strategy, independent of action templates.
class_name BattleSkillPassiveNode

@export_group("Passive payload")
@export var passive_stat_modifiers: Array[BattleSkillTreeStatGrant] = []
## Optional collections per rank. Effects must target SELF and last WHILE_SOURCE_ACTIVE.
@export var passive_effects_by_rank: Array[EffectTemplates] = []


func get_payload_label() -> String:
    return "Passive"


func accepts_predecessor(previous: BattleSkillNode) -> bool:
    return previous is BattleSkillPassiveNode


func validate_payload(errors: PackedStringArray) -> void:
    if passive_stat_modifiers.is_empty() and passive_effects_by_rank.is_empty():
        errors.append("Passive node %s has no payload." % id)
    var ids: Dictionary = {}
    for modifier in passive_stat_modifiers:
        if not modifier or modifier.modifier_id.is_empty() or ids.has(modifier.modifier_id):
            errors.append("Passive node %s requires unique modifier IDs." % id)
            continue
        ids[modifier.modifier_id] = true
        if (
            modifier.stat == CombatStats.STATS.Empty
            or modifier.stat not in CombatStats.STATS.values()
            or modifier.operation not in UnitStatModifier.OPERATION.values()
        ):
            errors.append("Passive node %s has an invalid stat/operation." % id)
        if modifier.amounts_by_rank.size() < maximum_rank:
            errors.append("Passive node %s needs a modifier amount for every rank." % id)
        for amount in modifier.amounts_by_rank:
            if not is_finite(amount):
                errors.append("Passive node %s has a nonfinite modifier amount." % id)
    if passive_effects_by_rank.is_empty():
        return
    if passive_effects_by_rank.size() < maximum_rank:
        errors.append("Passive node %s needs an effect collection for every rank." % id)
    for collection in passive_effects_by_rank:
        if not collection:
            errors.append("Passive node %s has a null effect collection." % id)
            continue
        var effect_ids: Dictionary = {}
        for effect in collection.all:
            BattleSkillPayloadValidator.validate_effect(effect, id, errors)
            if (
                effect
                and (
                    effect.lifetime != EffectTemplate.LIFETIME.WHILE_SOURCE_ACTIVE
                    or effect.target != CombatActions.TARGET.SELF
                )
            ):
                errors.append("Passive node %s effects must be SELF / WHILE_SOURCE_ACTIVE." % id)
            if effect:
                if effect_ids.has(effect.id):
                    errors.append("Passive node %s repeats an effect ID in one rank." % id)
                effect_ids[effect.id] = true


func append_chain_plan(
    _source: StringName,
    components: Array[BattleSkillNode],
    ledger: BattleSkillInvestment,
    _signature: Array,
    result: Dictionary
) -> void:
    for component in components:
        var key := StringName(
            (
                BattleSkillChainResolver.SOURCE_PREFIX
                + JSON.stringify([String(ledger.get_tree_id(component.id)), String(component.id)])
            )
        )
        result.passives[key] = {"node": component, "rank": ledger.get_rank(component.id)}


## Called only after the entire plan passes preflight.
func apply_grants(unit: BattleUnit, rank: int, source: StringName) -> void:
    for modifier in passive_stat_modifiers:
        unit.get_stat(modifier.stat).add_modifier(
            UnitStatModifier.create(
                StringName("%s:%s" % [source, modifier.modifier_id]),
                source,
                modifier.stat,
                modifier.operation,
                modifier.get_amount(rank),
                UnitStatModifier.LIFETIME.WHILE_SOURCE_ACTIVE,
                modifier.priority
            )
        )
    if not passive_effects_by_rank.is_empty():
        for effect in passive_effects_by_rank[rank - 1].all:
            unit.add_effect(unit, unit, effect, {"source_id": source})


func validate_grant_stats(unit: BattleUnit, errors: PackedStringArray) -> void:
    for modifier in passive_stat_modifiers:
        if not unit.get_stat(modifier.stat):
            errors.append("Unit lacks a passive grant stat.")
