# Checks generated Frenzy resources using real action, effect, round and retry services.
extends "res://editor_only_debug/scripts/debug/ranked_effect_modifiers_smoke_test.gd"

const FRENZY_PATH = "res://GrimDaysBattle/resources/actions/celine/frenzy_single_rank/frenzy_single_rank.tres"
const NODE_PATH = "res://GrimDaysBattle/resources/skill_trees/celine/troubled_youth/tier 3/frenzy_node.tres"


func _ready() -> void:
    # Runtime loading checks saved authored content, without eagerly coupling the fixture to it.
    var action := load(FRENZY_PATH) as ActionTemplate # lint:ignore load-in-var -- Load fixtures during test execution.
    var node := load(NODE_PATH) as BattleSkillActionNode # lint:ignore load-in-var,line-length -- Load fixtures during test execution.
    assert(node.action == action and node.icon == action.icon and node.description == action.description)
    assert(action.ranks.validate_progression().is_empty())
    var errors := PackedStringArray()
    node.validate_payload(errors)
    assert(errors.is_empty(), str(errors))
    for number in range(1, 6):
        await _verify_rank(action, number)
    _verify_validation(action)
    await _test_ranked_combat_modifiers()
    print("FRENZY_SMOKE_TEST: PASS") # lint:ignore debug-print -- Required test/CLI output.


func _verify_rank(action: ActionTemplate, number: int) -> void:
    var duration: int = [2, 2, 3, 3, 4][number - 1]
    var forced_duration := duration + 1  # Includes the round spent activating Frenzy.
    var rank := action.get_rank_template(number)
    var force := rank.effects.all[0] as EffectForceActionTemplate
    assert(rank.cost[CombatStats.STATS.Energy] == number + 1)
    assert(force.duration == forced_duration and force.action_rank == number)
    assert(force.effects_on_expiry.size() == 2)
    var restoration := force.effects_on_expiry[0] as EffectResourceChangeTemplate
    assert(restoration.amount_mode == EffectResourceChangeTemplate.AMOUNT_MODE.PERCENT_MAX)
    assert(restoration.amount == 0.5 and restoration.stat == CombatStats.STATS.Lucidity)
    assert(force.effects_on_expiry[1].duration == duration and force.effects_on_expiry[1].capture_current)
    var rush := force.action
    assert(rush.ranks.validate_progression().is_empty())
    var rush_rank := rush.get_rank_template(number)
    var strikes := rush_rank.effects.all[0] as EffectTriggerAnotherEffect
    assert(rush_rank.cost[CombatStats.STATS.Energy] == 20 + (number - 1) * 3)
    assert(strikes.repeat_min == (1 if number < 3 else 2))
    assert(strikes.repeat_max == (2 if number < 3 else (3 if number < 5 else 4)))
    assert(is_equal_approx(strikes.triggers[0].scales_by, -1.0 - 0.05 * (number - 1)))
    var f := _fixture(1)
    _prepare(f)
    f.actor.player_controlled = true
    _override_stat(f.actor, CombatStats.STATS.PhysicalDamage, 10)
    _override_stat(f.actor, CombatStats.STATS.DamageModifier, 1)
    _override_stat(f.actor, CombatStats.STATS.Accuracy, 100)
    var energy: UnitGenericStat = f.actor.get_stat(CombatStats.STATS.Energy)
    var lucidity: UnitGenericStat = f.actor.get_stat(CombatStats.STATS.Lucidity)
    lucidity.set_base(100)
    lucidity.restore_current(80)
    assert(f.actor.grant_action_from_source(&"frenzy_fixture", action, number))
    var cast: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"frenzy_cast", f.actor, action, [f.actor])
    )
    assert(cast.success, cast.error)
    assert(energy.Current == 100 - (number + 1))
    assert(not f.actor.player_controlled)
    var mandate: EffectForceAction = f.actor.get_forced_action_effect()
    assert(mandate != null and mandate.duration == forced_duration and mandate.definition.action_rank == number)
    assert(f.foes[0].get_forced_action_effect() == null)
    energy.restore_current(0)
    for count in range(strikes.repeat_min, strikes.repeat_max + 1):
        f.foes[0].get_stat(CombatStats.STATS.Health).restore_current(100)
        f.actor.randomizer.random_number_generator.seed = _repeat_seed(strikes, count)
        var request := BattleActionRequest.new(&"frenzied_rush", f.actor, rush, f.foes)
        assert(request.forced_action and request.free_action and request.get_execution_rank() == number)
        var result: BattleActionResolution = await f.resolver.resolve(request)
        assert(result.success, result.error)
        assert(result.get_events(BattleCombatEvent.TYPE.COST_PAID).is_empty() and energy.Current == 0)
        var hits := result.get_events(BattleCombatEvent.TYPE.DAMAGE)
        assert(hits.size() + result.get_events(BattleCombatEvent.TYPE.MISS).size() == count)
        assert(not hits.is_empty())
        for hit in hits:
            assert(hit.target == f.foes[0])
            assert(is_equal_approx(hit.data.raw_change, -10.0 * (1.0 + 0.05 * (number - 1))))
    lucidity.restore_current(80 if number == 5 else 37)
    var expected_lucidity := minf(lucidity.Max, lucidity.Current + lucidity.Max * 0.5)
    var foe_lucidity: float = f.foes[0].get_stat(CombatStats.STATS.Lucidity).Current
    for boundary in range(forced_duration - 1):
        f.actor.effect_manager.advance_round()
        assert(f.actor.get_forced_action_effect() != null and not f.actor.player_controlled)
        assert(lucidity.current_locks.is_empty())
    var expiry_source := StringName("expiry:%s:%s" % [mandate.source_id, mandate.id])
    f.actor.effect_manager.advance_round()
    assert(f.actor.get_forced_action_effect() == null and f.actor.player_controlled)
    var locks: Array = f.actor.effect_manager.get_effects_from_source(expiry_source)
    assert(locks.size() == 1 and locks[0].duration == duration)
    assert(
        (
            lucidity.Current == expected_lucidity
            and f.foes[0].get_stat(CombatStats.STATS.Lucidity).current_locks.is_empty()
        )
    )
    assert(f.foes[0].get_stat(CombatStats.STATS.Lucidity).Current == foe_lucidity)
    lucidity.decrease_current_flat(20)
    lucidity.increase_current_flat(10)
    assert(lucidity.Current == expected_lucidity)
    assert(locks[0].get_description() == "Lucidity remains fixed at %d." % int(expected_lucidity))
    var checkpoint := BattleRetryCheckpoint.new()
    checkpoint.capture([f.actor])
    for boundary in range(duration):
        f.actor.effect_manager.advance_round()
    assert(lucidity.current_locks.is_empty())
    lucidity.restore_current(12)
    await get_tree().process_frame
    assert(checkpoint.restore())
    assert(lucidity.Current == expected_lucidity)
    for boundary in range(duration):
        f.actor.effect_manager.advance_round()
    assert(lucidity.current_locks.is_empty())
    lucidity.decrease_current_flat(1)
    assert(lucidity.Current == expected_lucidity - 1)
    # Manual removal must not create the natural-expiry benefit.
    var removed: EffectBase = f.actor.add_effect(f.actor, f.actor, force)
    removed.apply()
    removed.remove()
    assert(lucidity.Current == expected_lucidity - 1, "Manual removal must not restore Lucidity.")
    assert(lucidity.current_locks.is_empty() and f.actor.player_controlled)
    await _free_fixture(f)


func _repeat_seed(chain: EffectTriggerAnotherEffect, count: int) -> int:
    var probe := RandomNumberGenerator.new()
    for candidate in range(1000):
        probe.seed = candidate
        if probe.randi_range(chain.repeat_min, chain.repeat_max) == count:
            return candidate
    assert(false, "Expected a seed for each inclusive repeat count.")
    return 0


func _verify_validation(action: ActionTemplate) -> void:
    var rank := action.get_rank_template(1)
    var force := rank.effects.all[0] as EffectForceActionTemplate
    force.action_rank_by_rank = PackedInt32Array([6])
    assert(not PROGRESSION.validate(rank, {}, 5).is_empty())
    force.action_rank_by_rank = PackedInt32Array([2])
    assert(PROGRESSION.validate(rank, {}, 5).is_empty())
    assert(PROGRESSION.resolve(rank, {}, 5).effects.all[0].action_rank == 2)
    var rush_rank := force.action.get_rank_template(1)
    var chain := rush_rank.effects.all[0] as EffectTriggerAnotherEffect
    chain.repeat_min_by_rank = PackedInt32Array([3])
    chain.repeat_max_by_rank = PackedInt32Array([2])
    assert(not PROGRESSION.validate(rush_rank, {}, 5).is_empty())
    chain.repeat_max_by_rank = PackedInt32Array([4])
    assert(PROGRESSION.validate(rush_rank, {}, 5).is_empty())
    assert(PROGRESSION.resolve(rush_rank, {}, 5).effects.all[0].repeat_min == 3)
    assert(action.ranks.base_rank.effects.all[0].action_rank == 1)
