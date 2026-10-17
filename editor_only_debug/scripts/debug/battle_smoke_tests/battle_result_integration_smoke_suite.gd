extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"


## Runs the battle result integration smoke checks. Creates or uses test objects and stops on failed
## assertions.
func run() -> void:
    await _test_controller_finalization_and_cleanup()
    await _test_source_less_defeat_skips_kill_effects()


## Checks controller finalization and cleanup using test objects and assertions. A failed assertion
## identifies behavior that no longer meets the test’s expectation.
func _test_controller_finalization_and_cleanup() -> void:
    var previous_allies = BattleController.ally_unit_holder
    var previous_foes = BattleController.foe_unit_holder
    var previous_presentation = BattleController.presentation_adapter
    var previous_current = BattleController.current_battle_result
    var previous_last = BattleController.last_battle_result

    var arena := Node.new()
    var allies := UnitPartyDebug.new()
    var foes := UnitPartyDebug.new()
    arena.add_child(allies)
    arena.add_child(foes)
    add_child(arena)
    var ally := BattleUnit.create(CELINE_TEMPLATE)
    var foe := BattleUnit.create(CELINE_TEMPLATE)
    allies.add_child(ally)
    foes.add_child(foe)
    foe.get_stat(CombatStats.STATS.Health).decrease_current_flat(foe.get_stat(CombatStats.STATS.Health).Max)

    BattleController.ally_unit_holder = allies
    BattleController.foe_unit_holder = foes
    BattleController.clear_presentation_adapter()
    BattleController.current_battle_result = null
    assert(SaveAndLoadSystemManager.can_save_game())
    var emitted: Array = []
    var collect_result := func(sent_result): emitted.append(sent_result)
    BattleController.battle_finished.connect(collect_result)
    var return_context := {"caller": "smoke"}
    var authored_rewards := {"experience": 25, "items": [&"test_reward"]}
    (
        BattleController
        . begin_battle_session(
            &"controller_result",
            2468,
            return_context,
            authored_rewards,
        )
    )
    assert(not SaveAndLoadSystemManager.can_save_game())
    assert(not SaveAndLoadSystemManager.get_save_block_reason().is_empty())
    var rejected_saves: Array[String] = []
    var collect_rejection := func(reason: String): rejected_saves.append(reason)
    SaveAndLoadSystemManager.save_rejected.connect(collect_rejection)
    assert(not await SaveAndLoadSystemManager.save_game("blocked_battle_save", "Blocked Battle Save"))
    assert(not SaveAndLoadSystemManager.save_checkpoint())
    assert(rejected_saves.size() == 2 and rejected_saves[0] == rejected_saves[1])
    SaveAndLoadSystemManager.save_rejected.disconnect(collect_rejection)
    return_context.caller = "mutated"
    authored_rewards["items"].append(&"late_mutation")
    BattleController.record_round_started()
    BattleController.record_turn_started()
    var result = BattleController.finish_battle(BattleResult.OUTCOME.VICTORY)

    assert(result.finalized and result.is_victory())
    assert(result.encounter_id == &"controller_result" and result.battle_seed == 2468)
    assert(result.rounds == 1 and result.turns == 1)
    assert(result.return_context == {"caller": "smoke"})
    assert(result.rewards == {"experience": 25, "items": [&"test_reward"]})
    assert(result.winning_teams == [&"allies"] and result.defeated_teams == [&"foes"])
    assert(result.surviving_allies == [ally] and result.defeated_units == [foe])
    assert(result.ally_snapshots.size() == 1 and result.ally_snapshots[0].active)
    assert(result.foe_snapshots.size() == 1 and not result.foe_snapshots[0].active)
    assert(result.ally_snapshots[0].team_id == ally.team_id)
    assert(emitted == [result], "A terminal phase must publish a result exactly once.")
    assert(BattleController.finish_battle(BattleResult.OUTCOME.DEFEAT) == result)
    assert(emitted == [result], "Repeated terminal execution must not emit twice.")
    assert(
        not SaveAndLoadSystemManager.can_save_game(),
        "Finalization must remain unsaveable until cleanup restores party ownership."
    )

    BattleController.cleanup_battle()
    assert(allies.get_child_count() == 0 and foes.get_child_count() == 0)
    assert(BattleController.current_battle_result == null)
    assert(SaveAndLoadSystemManager.can_save_game())
    assert(result.ally_snapshots[0].active and not result.foe_snapshots[0].active)
    BattleController.battle_finished.disconnect(collect_result)
    BattleController.ally_unit_holder = previous_allies
    BattleController.foe_unit_holder = previous_foes
    BattleController.set_presentation_adapter(previous_presentation)
    BattleController.current_battle_result = previous_current
    BattleController.last_battle_result = previous_last
    await free_node(arena)


## Checks source less defeat skips kill effects using test objects and assertions. A failed
## assertion identifies behavior that no longer meets the test’s expectation.
func _test_source_less_defeat_skips_kill_effects() -> void:
    var defeated := create_unit()
    create_flat_stat(defeated, CombatStats.STATS.Health, 1.0)
    defeated.get_stat(CombatStats.STATS.Health).decrease_current_flat(1.0)
    assert(defeated.last_hit_by == null)
    var phase := BattlePhaseProcessKill.new()
    await phase.trigger_kill_effects_for(defeated)
    phase.free()
    await free_node(defeated)
