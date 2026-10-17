# Verifies the authored Heavy Blows action independently of unfinished skill payloads.
extends "res://editor_only_debug/scripts/debug/ranked_effect_modifiers_smoke_test.gd"

const HEAVY_BLOWS_PATH = "res://GrimDaysBattle/resources/actions/celine/heavy_blows_single_rank/heavy_blows_single_rank.tres" # lint:ignore line-length -- Preserve resource path or authored text.


func _ready() -> void:
    # Load authored content at runtime so this fixture observes the current saved resources.
    var action := load(HEAVY_BLOWS_PATH) as ActionTemplate # lint:ignore load-in-var,line-length -- Load fixtures during test execution.
    assert(action != null and action.ranks.get_rank_count() == 5)
    assert(action.ranks.validate_progression().is_empty())
    for number in range(1, 6):
        var chance := 15 + number * 5
        var chain := action.get_rank_template(number).effects.all[0] as EffectTriggerAnotherEffect
        assert(chain != null and chain.chance == chance)
        assert(chain.triggers.size() == 1 and chain.triggers[0] is EffectDelayTurnTemplate)
        for succeeds in [true, false]:
            await _verify_roll(action, number, chance, succeeds)
    assert(action.ranks.base_rank.effects.all[0].chance == 20)
    print("HEAVY_BLOWS_SMOKE_TEST: PASS (ranks 1-5, success/failure, selected-target delay)") # lint:ignore debug-print,line-length -- Required test/CLI output.


func _verify_roll(action: ActionTemplate, number: int, chance: int, succeeds: bool) -> void:
    var f := _fixture(3)
    _override_stat(f.actor, CombatStats.STATS.Swiftness, 1000)
    var coordinator: BattleCoordinator = f.scene.coordinator
    assert(coordinator.begin_round(coordinator.session_id))
    assert(coordinator.record_turn_started(coordinator.session_id))
    assert(coordinator.turn_order.get_active_unit() == f.actor)
    var before := coordinator.turn_order.get_units()
    var target: BattleUnit = before[1]
    assert(f.actor.grant_action_from_source(&"heavy_blows_fixture", action, number))
    # Select a seed whose first sample lies immediately on either side of this rank's threshold.
    var probe := RandomNumberGenerator.new()
    var selected_seed: int = -1
    for candidate in range(100000):
        probe.seed = candidate
        var sample := probe.randf_range(0.0, 100.0)
        if (
            (succeeds and sample >= chance - 1 and sample < chance)
            or (not succeeds and sample >= chance and sample < chance + 1)
        ):
            selected_seed = candidate
            break
    assert(selected_seed >= 0)
    f.actor.randomizer.random_number_generator.seed = selected_seed
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"heavy_blows_check", f.actor, action, [target])
    )
    assert(result.success)
    var delays := result.get_events(BattleCombatEvent.TYPE.TURN_DELAY)
    assert(delays.size() == (1 if succeeds else 0), "Rank %s chance boundary failed" % number)
    var expected: Array = [before[0], before[2], before[1], before[3]] if succeeds else before
    assert(coordinator.turn_order.get_units() == expected)
    assert(coordinator.current_result.turns == 1, "Delay must not consume another turn.")
    await _free_fixture(f)
