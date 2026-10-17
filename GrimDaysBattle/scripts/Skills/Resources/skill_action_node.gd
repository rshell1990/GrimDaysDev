# Editor configuration for BattleSkillActionNode.
@tool
extends BattleSkillNode
## Active skill payload strategy. Shared layout and investment data live on BattleSkillNode.
class_name BattleSkillActionNode

@export_group("Action payload")
## Explicit or generated payloads must resolve for every purchasable rank.
@export var action: ActionTemplate


func get_payload_label() -> String:
    return "Action"


func has_action_source() -> bool:
    return true


func accepts_predecessor(previous: BattleSkillNode) -> bool:
    return previous is BattleSkillActionNode


func validate_payload(errors: PackedStringArray) -> void:
    if not action or action.id.is_empty():
        errors.append("Action node %s requires an identified ActionTemplate." % id)
        return
    errors.append_array(action.validate_restrictions())
    if action.ranks:
        var progression_errors := action.ranks.validate_progression()
        errors.append_array(progression_errors)
        if not progression_errors.is_empty():
            return
    for number in range(1, maximum_rank + 1):
        var rank := action.get_rank_template(number)
        if not rank:
            errors.append("Action node %s is missing rank %s." % [id, number])
            continue
        if rank.cooldown_turns < 0:
            errors.append("Action node %s has a negative cooldown." % id)
        for stat in rank.cost:
            if stat == CombatStats.STATS.Empty or stat not in CombatStats.STATS.values() or rank.cost[stat] < 0:
                errors.append("Action node %s has an invalid cost." % id)
        if rank.effects:
            for effect in rank.effects.all:
                BattleSkillPayloadValidator.validate_effect(effect, id, errors)
                if effect and effect.trigger == CombatEffects.TRIGGER.EQUIP:
                    errors.append("Action node %s cannot contain EQUIP operations." % id)


func append_chain_plan(
    source: StringName,
    components: Array[BattleSkillNode],
    ledger: BattleSkillInvestment,
    signature: Array,
    result: Dictionary
) -> void:
    var compiled := _compile_action(source, components, ledger, result.errors)
    if compiled:
        result.actions[source] = {"action": compiled, "rank": ledger.get_rank(id), "tip": id, "signature": signature}


## Builds an independent action for the purchased chain: summed costs/effects, first-component
## animation and tip targeting/cooldown. Uses a stable source ID; appends an error and returns null
## if cost addition overflows.
func _compile_action(
    source: StringName, components: Array[BattleSkillNode], ledger: BattleSkillInvestment, errors: PackedStringArray
) -> ActionTemplate:
    var highest: BattleSkillActionNode = components.back()
    var highest_rank := ledger.get_rank(highest.id)
    var definition: ActionTemplate = highest.action
    var compiled := ActionTemplate.new()
    # Stable across tier fallback and rank changes: cooldowns cannot be bypassed by
    # toggling Sanity, and these generated IDs cannot collide with story actions.
    compiled.id = source
    compiled.display_name = highest.display_name if not highest.display_name.is_empty() else definition.display_name
    compiled.description = definition.description
    compiled.icon = definition.icon
    compiled.target = definition.target
    compiled.include_self = definition.include_self
    compiled.target_amount = definition.target_amount
    compiled.type = definition.type
    compiled.risk_reward = definition.risk_reward
    # Legacy compatibility override; leaf effects also support always_hits.
    compiled.always_hits = definition.always_hits
    var opening_action := (components.front() as BattleSkillActionNode).action
    compiled.attack_animation = opening_action.attack_animation
    compiled.use_spine = opening_action.use_spine
    compiled.loop = opening_action.loop
    compiled.track_number = opening_action.track_number
    var rank := RankTemplate.new()
    rank.level = highest_rank
    rank.cooldown_turns = definition.get_rank_template(highest_rank).cooldown_turns
    rank.effects = EffectTemplates.new()
    for component in components:
        var component_action := (component as BattleSkillActionNode).action
        compiled.equipment_requirements.append_array(component_action.equipment_requirements)
        for effect_id in component_action.disabled_by_effects:
            if effect_id not in compiled.disabled_by_effects:
                compiled.disabled_by_effects.append(effect_id)
        var part: RankTemplate = component_action.get_rank_template(ledger.get_rank(component.id))
        for stat in part.cost:
            var previous: int = rank.cost.get(stat, 0)
            if part.cost[stat] > 2147483647 - previous:
                errors.append("Composite action %s cost exceeds the supported range." % highest.id)
                return null
            rank.cost[stat] = previous + part.cost[stat]
        if part.effects:
            rank.effects.all.append_array(part.effects.all)
    compiled.ranks = RanksTemplate.new()
    # Only the purchased rank is executable. Preserve the tip's displayed rank;
    # never synthesize unrelated lower-rank combinations from this snapshot.
    compiled.ranks.all.resize(highest_rank)
    compiled.ranks.all[highest_rank - 1] = rank
    compiled.set_meta(&"project_skill_compiled", true)
    return compiled


## Node overrides take precedence over shared action presentation.
func get_display_name() -> String:
    if display_name.is_empty() and action and not action.display_name.is_empty():
        return action.display_name
    return super.get_display_name()


func get_display_icon() -> Texture2D:
    return icon if icon else (action.icon if action else null)


func get_description() -> String:
    return description if not description.is_empty() else (action.description if action else "")
