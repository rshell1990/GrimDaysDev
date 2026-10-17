extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"

## Resource loaded for production battle scene; reused instead of looking up the file on each call.
const PRODUCTION_BATTLE_SCENE := preload("res://GrimDaysVN/scenes/root/battle.tscn")


class SynchronousRestoreStub:
    extends Node
    signal restored

    func restore(_data: Dictionary) -> void:
        restored.emit()


## Runs the runtime party smoke checks. Creates or uses test objects and stops on failed assertions.
func run() -> void:
    var restore_stub := SynchronousRestoreStub.new()
    add_child(restore_stub)
    await SaveAndLoadSystemManager._restore_node(restore_stub, {})
    await free_node(restore_stub)

    BattleController.cleanup_battle()
    var manager = BattleController.party_manager
    assert(manager, "BattleController must own a persistent runtime party manager.")
    var available: Array[BattleUnit] = manager.get_available_units()
    assert(not available.is_empty(), "Permanent unit templates must be created at runtime.")
    var celine: BattleUnit = manager.runtime_units.get(CELINE_TEMPLATE.id)
    assert(celine, "Celine is permanent and must be present in the runtime roster.")
    assert(manager.get_active_party() == [celine], "Permanent units must form the default active party.")
    assert(not manager.set_active_party([CELINE_TEMPLATE.id, CELINE_TEMPLATE.id]))
    assert(not manager.set_active_party([&"missing_unit"]))

    var strength := celine.get_stat(CombatStats.STATS.Strength)
    var health := celine.get_stat(CombatStats.STATS.Health)
    strength.set_base(strength.Base + 2.0)
    (
        strength
        . add_modifier(
            (
                UnitStatModifier
                . create(
                    &"persistent_party_test",
                    &"skill:persistent_party_test",
                    CombatStats.STATS.Strength,
                    UnitStatModifier.OPERATION.FLAT_ADD,
                    3.0,
                    UnitStatModifier.LIFETIME.PERSISTENT,
                )
            )
        )
    )
    health.decrease_current_flat(10.0)
    var basic_action: ActionTemplate = celine.get_basic_action()
    assert(celine.learn_action(basic_action, 1))
    celine._action_cooldowns[basic_action.id] = 3
    var saved_state: Dictionary = manager._get_state()
    var saved_strength_base: float = strength.Base
    var saved_health_current: float = health.Current

    manager.restore(saved_state)
    var restored: BattleUnit = manager.runtime_units.get(CELINE_TEMPLATE.id)
    assert(restored and restored != celine, "Loading must reconstruct permanent runtime units.")
    assert(is_equal_approx(restored.get_stat(CombatStats.STATS.Strength).Base, saved_strength_base))
    assert(
        restored.get_stat(CombatStats.STATS.Strength).mods.has(&"persistent_party_test"),
        "Persistent modifier ledger entries must survive reconstruction.",
    )
    assert(is_equal_approx(restored.get_stat(CombatStats.STATS.Health).Current, saved_health_current))
    assert(restored.is_action_learned(basic_action), "Learned action ownership must survive reconstruction.")
    assert(restored.get_action_rank(basic_action) == 1, "Learned action ranks must survive reconstruction.")
    assert(restored.get_action_cooldown(basic_action) == 3, "Action cooldowns must survive reconstruction.")
    assert(not restored.can_use_action(basic_action), "A restored cooldown must continue preventing action use.")
    assert(manager.get_active_party() == [restored])
    for turn in range(3):
        restored.on_turn_started()
    assert(restored.get_action_cooldown(basic_action) == 0)
    assert(restored.can_use_action(basic_action), "A restored cooldown must expire normally.")

    var queued := (
        BattleController
        . queue_battle(
            [CELINE_TEMPLATE],
            &"runtime_party_encounter",
            2468,
            {"source": "smoke_test"},
            {"experience": 50},
        )
    )
    assert(queued)
    var payload: Dictionary = BattleController.get_pending_battle_payload()
    assert(payload.allies == [restored], "Queued battle allies must come from current runtime state.")
    assert(payload.foes == [CELINE_TEMPLATE], "Only foe templates belong to the encounter payload.")
    assert(BattleController.current_battle_result.encounter_id == &"runtime_party_encounter")
    assert(BattleController.current_battle_result.battle_seed == 2468)
    assert(BattleController.current_battle_result.rewards == {"experience": 50})
    BattleController.cleanup_battle()
    var battle_scene: BattleEncounterScene = PRODUCTION_BATTLE_SCENE.instantiate()
    add_child(battle_scene)
    assert(
        battle_scene.begin_encounter(
            manager, [CELINE_TEMPLATE], &"runtime_party_encounter", 2468, {"source": "smoke_test"}, {"experience": 50}
        )
    )
    assert(battle_scene.coordinator.roster.get_allies() == [restored])
    assert(restored.get_parent() == manager, "Production battles borrow, never reparent, permanent allies.")
    var result := battle_scene.coordinator.finish(battle_scene.coordinator.session_id, BattleResult.OUTCOME.DRAW)
    assert(result and result.finalized)
    assert(result.encounter_id == &"runtime_party_encounter")
    assert(result.rewards == {"experience": 50}, "Production resolution must preserve encounter rewards.")
    battle_scene.coordinator.cleanup(battle_scene.coordinator.session_id)
    assert(BattleController.pending_foes.is_empty())
    assert(restored.get_parent() == manager, "Cleanup must preserve persistent ally ownership.")
    await free_node(battle_scene)
    manager.restore(saved_state)
