extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/skill_chain_smoke_suite.gd"
## Generated payloads, authoring validation, shared-resource isolation and existing consumer integration.

const PAYLOAD_PREVIEW = preload("res://GrimDaysBattle/scripts/Skills/UI/skill_payload_preview.gd")
const RESOURCE_EFFECT_SCENE = preload(
    "res://GrimDaysBattle/scenes/battle/effects/effect_change_resource.tscn"
)
const CHAIN_EFFECT_SCENE = preload("res://GrimDaysBattle/scenes/battle/effects/effect_trigger_chain.tscn")


func run() -> void:
    _test_effect_descriptions()
    _test_progression()
    _test_fields_and_chains()
    _test_validation()
    _test_roundtrip_and_compilation()
    await _test_unit_ranks()
    await _test_execution()
    print("ACTION_RANK_PROGRESSION_SMOKE_TEST: PASS") # lint:ignore debug-print -- Required test/CLI output.


func _test_effect_descriptions() -> void:
    var buff := EffectPercentageChangeStatTemplate.new()
    buff.percentage = 0.125
    buff.description = "Extra damage increased by x%; max stays intact. (x%)"
    assert(buff.get_description() == "Extra damage increased by 12.5%; max stays intact. (12.5%)")
    assert(buff.description == "Extra damage increased by x%; max stays intact. (x%)")
    buff.percentage = 0.0
    assert("by 0%" in buff.get_description())
    var drain := EffectResourceChangeTemplate.new()
    drain.stat = CombatStats.STATS.Lucidity
    drain.amount_mode = EffectResourceChangeTemplate.AMOUNT_MODE.PERCENT_MAX
    drain.amount = -0.175
    drain.description = "Lose x% of max Lucidity."
    assert(drain.get_description() == "Lose 17.5% of max Lucidity.")
    drain.amount_mode = EffectResourceChangeTemplate.AMOUNT_MODE.PERCENT_CURRENT
    assert(drain.get_description() == "Lose 17.5% of max Lucidity.")
    drain.amount_mode = EffectResourceChangeTemplate.AMOUNT_MODE.FLAT
    drain.amount = -25.0
    drain.description = "Lose x Lucidity."
    assert(drain.get_description() == "Lose 25 Lucidity.")
    var flat := EffectFlatChangeStatTemplate.new()
    flat.flat_amount = 3.5
    flat.description = "Gain x armor."
    assert(flat.get_description() == "Gain 3.5 armor.")
    var capped := EffectCappedChangeStatTemplate.new()
    capped.amount = 5.0
    capped.description = "Gain x armor."
    assert(capped.get_description() == "Gain 5 armor.")
    var chain := EffectTriggerAnotherEffect.new()
    chain.chance = 35
    chain.description = "x% chance."
    chain.triggers = [drain]
    assert(chain.get_description() == "35% chance.")
    assert("Lucidity lost: 25" in PAYLOAD_PREVIEW.effect_text(chain))
    var unsupported := EffectTemplate.new()
    unsupported.description = "x stays x; extra, max, x_axis and X stay intact."
    assert(unsupported.get_description() == unsupported.description)
    var action := _generated_action()
    var damage: EffectScalingCombatStatChangeTemplate = action.ranks.base_rank.effects.all[0]
    damage.description = "Deals x% of damage (multiplier x)."
    var first := action.get_rank_template(1)
    var fifth := action.get_rank_template(5)
    assert(first.effects.all[0].get_description() == "Deals 105% of damage (multiplier 1.05).")
    assert(fifth.effects.all[0].get_description() == "Deals 125% of damage (multiplier 1.25).")
    assert("Damage: 125% of your Physical Damage" in PAYLOAD_PREVIEW.action_text(action, 5))
    assert(
        (
            "Damage: 105% of your Physical Damage -> Damage: 110% of your Physical Damage"
            in PAYLOAD_PREVIEW.next_text(_node_for(action), 1)
        )
    )
    assert(damage.description == "Deals x% of damage (multiplier x).")
    assert(first.effects.all[0].get_description() == "Deals 105% of damage (multiplier 1.05).")
    damage.description = "Fixed text without a placeholder."
    assert(damage.get_description() == damage.description)


func _generated_action() -> ActionTemplate:
    var action := _action(&"generated_action", 1, 0)
    var ranks := action.ranks
    ranks.generated = true
    ranks.rank_count = 5
    ranks.base_rank = ranks.all[0]
    ranks.all = []
    ranks.base_rank.cost[CombatStats.STATS.Energy] = 25
    ranks.cost_increase_per_rank[CombatStats.STATS.Energy] = 5
    var damage: EffectScalingCombatStatChangeTemplate = ranks.base_rank.effects.all[0]
    damage.scales_by_by_rank = PackedFloat64Array([-1.05, -1.10, -1.15, -1.20, -1.25])
    return action


func _test_progression() -> void:
    var action := _generated_action()
    assert(action.ranks.validate_progression().is_empty())
    assert(action.get_rank_count() == 5)
    assert(action.get_rank_template(0) == null and action.get_rank_template(6) == null)
    for number in range(1, 6):
        var rank := action.get_rank_template(number)
        assert(rank.level == number)
        assert(rank.cost[CombatStats.STATS.Energy] == 20 + 5 * number)
        assert(is_equal_approx(rank.effects.all[0].scales_by, -1.0 - number * 0.05))
    var first := action.get_rank_template(1)
    var fifth := action.get_rank_template(5)
    first.cost[CombatStats.STATS.Energy] = 999
    first.effects.all[0].scales_by = 999.0
    first.effects.all.clear()
    assert(fifth.effects.all.size() == 1)
    assert(is_equal_approx(fifth.effects.all[0].scales_by, -1.25))
    assert(action.get_rank_template(1).cost[CombatStats.STATS.Energy] == 25)
    assert(is_equal_approx(action.ranks.base_rank.effects.all[0].scales_by, -0.1))
    action.ranks.cost_increase_per_rank[CombatStats.STATS.Energy] = 7
    assert(action.get_rank_template(5).cost[CombatStats.STATS.Energy] == 53)
    var text := PAYLOAD_PREVIEW.action_text(action, 5)
    assert("53 Energy" in text and "Damage: 125% of your Physical Damage" in text)
    assert("by_rank" not in text and "By Rank" not in text and "Available From Rank" not in text)
    assert("Cost: 25 -> 32 Energy" in PAYLOAD_PREVIEW.next_text(_node_for(action), 1))
    # Legacy ranks ignore all progression fields and preserve object identity.
    action.ranks.all = [action.ranks.base_rank]
    action.ranks.generated = false
    assert(action.get_rank_count() == 1)
    assert(action.get_rank_template(1) == action.ranks.base_rank)
    assert(is_equal_approx(action.get_rank_template(1).effects.all[0].scales_by, -0.1))


func _node_for(action: ActionTemplate) -> BattleSkillActionNode:
    var node := BattleSkillActionNode.new()
    node.id = &"generated_node"
    node.maximum_rank = 5
    node.action = action
    return node


func _test_fields_and_chains() -> void:
    var action := _generated_action()
    var buff := EffectPercentageChangeStatTemplate.new()
    buff.id = &"ranked_buff"
    buff.template_scene = STAT_EFFECT_SCENE
    buff.trigger = CombatEffects.TRIGGER.ATTACKING
    buff.lifetime = EffectTemplate.LIFETIME.ROUNDS
    buff.duration_by_rank = PackedInt32Array([2, 2, 3, 3, 4])
    buff.percentage_by_rank = PackedFloat64Array([0.05, 0.1])
    buff.available_from_rank = 3
    action.ranks.base_rank.effects.all.append(buff)
    assert(action.get_rank_template(2).effects.all.size() == 1)
    var third := action.get_rank_template(3)
    assert(third.effects.all.size() == 2 and third.effects.all[1].duration == 3)
    assert(is_equal_approx(third.effects.all[1].percentage, 0.1))
    assert(action.get_rank_template(5).effects.all[1].duration == 4)
    var resource := EffectResourceChangeTemplate.new()
    resource.amount = 8.0
    resource.amount_by_rank = PackedFloat64Array([10.0, 20.0])
    var flat := EffectFlatChangeStatTemplate.new()
    flat.flat_amount_by_rank = PackedFloat64Array([1.0, 2.0])
    var capped := EffectCappedChangeStatTemplate.new()
    capped.amount_by_rank = PackedFloat64Array([3.0, 4.0])
    var chain := EffectTriggerAnotherEffect.new()
    chain.id = &"chain"
    chain.template_scene = CHAIN_EFFECT_SCENE
    chain.trigger = CombatEffects.TRIGGER.DAMAGED
    chain.triggers = [resource, flat, capped]
    for index in chain.triggers.size():
        var child := chain.triggers[index]
        child.id = StringName("child_%s" % index)
        child.template_scene = RESOURCE_EFFECT_SCENE if index == 0 else STAT_EFFECT_SCENE
        child.trigger = CombatEffects.TRIGGER.DAMAGED
    flat.available_from_rank = 2
    action.ranks.base_rank.effects.all.append(chain)
    var rank_one_chain: EffectTriggerAnotherEffect = action.get_rank_template(1).effects.all.back()
    var rank_five_chain: EffectTriggerAnotherEffect = action.get_rank_template(5).effects.all.back()
    assert(rank_one_chain.triggers.size() == 2)
    assert(rank_five_chain.triggers.size() == 3)
    assert(rank_five_chain.triggers[0].amount == 20.0)
    assert(rank_five_chain.triggers[1].flat_amount == 2.0)
    assert(rank_five_chain.triggers[2].amount == 4.0)
    assert(rank_five_chain.triggers[2].contribution_cap == capped.contribution_cap)
    rank_five_chain.triggers[0].amount = 999.0
    assert(rank_one_chain.triggers[0].amount == 10.0 and resource.amount == 8.0)
    resource.amount_by_rank = PackedFloat64Array()
    assert(action.get_rank_template(5).effects.all.back().triggers[0].amount == 8.0)


func _test_validation() -> void:
    var action := _generated_action()
    var ranks := action.ranks
    ranks.rank_count = 0
    assert(not ranks.validate_progression().is_empty())
    ranks.rank_count = 5
    ranks.cost_increase_per_rank[CombatStats.STATS.Energy] = 2147483647
    assert(not ranks.validate_progression().is_empty() and action.get_rank_template(1) == null)
    ranks.cost_increase_per_rank[CombatStats.STATS.Energy] = -1
    assert(not ranks.validate_progression().is_empty())
    ranks.cost_increase_per_rank[CombatStats.STATS.Energy] = 5
    ranks.cost_increase_per_rank[CombatStats.STATS.Empty] = 1
    assert(not ranks.validate_progression().is_empty())
    ranks.cost_increase_per_rank.erase(CombatStats.STATS.Empty)
    var damage: EffectScalingCombatStatChangeTemplate = ranks.base_rank.effects.all[0]
    damage.scales_by_by_rank[0] = INF
    assert(not ranks.validate_progression().is_empty())
    damage.scales_by_by_rank[0] = -1.05
    damage.available_from_rank = 6
    assert(not ranks.validate_progression().is_empty())
    damage.available_from_rank = 1
    damage.lifetime = EffectTemplate.LIFETIME.ROUNDS
    assert(not ranks.validate_progression().is_empty())
    damage.duration_by_rank = PackedInt32Array([2])
    assert(ranks.validate_progression().is_empty())
    var chain := EffectTriggerAnotherEffect.new()
    chain.id = &"cycle"
    chain.template_scene = CHAIN_EFFECT_SCENE
    chain.trigger = CombatEffects.TRIGGER.DAMAGED
    chain.triggers = [chain]
    ranks.base_rank.effects.all.append(chain)
    assert(not ranks.validate_progression().is_empty() and action.get_rank_template(1) == null)
    chain.triggers.clear()
    ranks.base_rank.effects.all.pop_back()
    var cursor := chain
    for index in 17:
        var child := EffectTriggerAnotherEffect.new()
        child.id = StringName("deep_%s" % index)
        child.template_scene = CHAIN_EFFECT_SCENE
        child.trigger = CombatEffects.TRIGGER.DAMAGED
        cursor.triggers = [child]
        cursor = child
    ranks.base_rank.effects.all.append(chain)
    assert(not ranks.validate_progression().is_empty())
    assert(not BattleSkillPayloadValidator.validate([_node_for(action)]).is_empty())


func _test_roundtrip_and_compilation() -> void:
    var action := _generated_action()
    var path := "user://action_progression_%s.tres" % Time.get_ticks_usec()
    assert(ResourceSaver.save(action, path) == OK)
    var restored := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ActionTemplate
    assert(restored and restored.ranks.generated and restored.ranks.all.is_empty())
    assert(restored.get_rank_template(5).cost[CombatStats.STATS.Energy] == 45)
    assert(is_equal_approx(restored.get_rank_template(5).effects.all[0].scales_by, -1.25))
    assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK)
    var fixture := _fixture()
    var node: BattleSkillActionNode = fixture.collection.trees[0].tiers[0].nodes[0]
    node.action = restored
    fixture.collection.trees[0].tiers[2].nodes[0].composite = true
    assert(BattleSkillPayloadValidator.validate([node]).is_empty())
    var plan := BattleSkillChainResolver.resolve(fixture.ledger, fixture.values)
    assert(plan.errors.is_empty())
    var entry := _tip(plan, &"a3")
    assert(not entry.is_empty())
    var payload: RankTemplate = entry.action.get_rank_template(entry.rank)
    assert(payload.cost[CombatStats.STATS.Energy] == 60)
    assert(is_equal_approx(payload.effects.all[0].scales_by, -1.10))


func _test_unit_ranks() -> void:
    var first := create_unit()
    var second := create_unit()
    create_flat_stat(first, CombatStats.STATS.Energy, 100.0)
    create_flat_stat(second, CombatStats.STATS.Energy, 100.0)
    var action := _generated_action()
    assert(first.learn_action(action, 1) and second.learn_action(action, 5))
    assert(first.get_action_rank(action) == 1 and second.get_action_rank(action) == 5)
    assert(first.pay_action_cost(action) and second.pay_action_cost(action))
    assert(first.get_stat(CombatStats.STATS.Energy).Current == 75.0)
    assert(second.get_stat(CombatStats.STATS.Energy).Current == 55.0)
    assert(not first.can_use_action(action))
    first.on_turn_started()
    assert(not first.can_use_action(action))
    first.on_turn_started()
    assert(first.can_use_action(action))
    assert(second.get_action_rank(action) == 5)
    assert(first.learn_action(action, 99) and first.get_action_rank(action) == 5)
    await free_node(first)
    await free_node(second)


func _test_execution() -> void:
    var actor := BattleUnit.create(CELINE_TEMPLATE)
    add_child(actor)
    var resolver := BattleActionResolver.new()
    add_child(resolver)
    var action := _generated_action()
    action.target = CombatActions.TARGET.SELF
    action.ranks.base_rank.cooldown_turns = 0
    var restore := EffectResourceChangeTemplate.new()
    restore.id = &"generated_restore"
    restore.template_scene = RESOURCE_EFFECT_SCENE
    restore.trigger = CombatEffects.TRIGGER.DAMAGED
    restore.stat = CombatStats.STATS.Energy
    restore.kind = CombatEffects.KIND.ONCE
    restore.amount_by_rank = PackedFloat64Array([3.0, 7.0])
    action.ranks.base_rank.effects.all = [restore]
    var energy := actor.get_stat(CombatStats.STATS.Energy)
    # Start at a whole pool value so the resource's normal rounding does not obscure progression.
    energy.decrease_current_flat(energy.Current - 100.0)
    assert(actor.learn_action(action, 2))
    var before := energy.Current
    var request := BattleActionRequest.new(&"generated_execution", actor, action, [actor])
    var resolution: BattleActionResolution = await resolver.resolve(request)
    assert(resolution.success, resolution.error)
    assert(
        is_equal_approx(energy.Current, before - 30.0 + 7.0),
        (
            "Generated execution: energy %s -> %s, expected %s; events %s"
            % [before, energy.Current, before - 23.0, resolution.events]
        )
    )
    assert(resolution.get_events(BattleCombatEvent.TYPE.COST_PAID).size() == 1)
    await free_node(resolver)
    await free_node(actor)
