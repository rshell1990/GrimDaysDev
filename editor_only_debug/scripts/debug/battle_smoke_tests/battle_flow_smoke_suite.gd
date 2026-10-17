extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"


## Runs the battle flow smoke checks. Creates or uses test objects and stops on failed assertions.
func run() -> void:
    await _test_target_selection()
    _test_immutable_target_cursor()
    _test_phase_exit_handoff_is_one_shot()
    _test_round_presentation_correlation()
    _test_headless_turn_order()


## Checks target selection using test objects and assertions. A failed assertion identifies behavior
## that no longer meets the test’s expectation.
func _test_target_selection() -> void:
    var battlefield := Node.new()
    var allies := UnitPartyDebug.new()
    var foes := UnitPartyDebug.new()
    allies.name = &"Allies"
    foes.name = &"Foes"
    battlefield.add_child(allies)
    battlefield.add_child(foes)
    add_child(battlefield)
    var active: BattleUnit = UNIT_SCENE.instantiate()
    var ally: BattleUnit = UNIT_SCENE.instantiate()
    var first_foe: BattleUnit = UNIT_SCENE.instantiate()
    var second_foe: BattleUnit = UNIT_SCENE.instantiate()
    allies.add_child(active)
    allies.add_child(ally)
    foes.add_child(first_foe)
    foes.add_child(second_foe)
    for combatant: BattleUnit in [active, ally, first_foe, second_foe]:
        create_flat_stat(combatant, CombatStats.STATS.Health, 10.0)
    active.template_resource = CELINE_TEMPLATE
    var old_allies: UnitPartyDebug = BattleController.ally_unit_holder
    var old_foes: UnitPartyDebug = BattleController.foe_unit_holder
    BattleController.ally_unit_holder = allies
    BattleController.foe_unit_holder = foes
    assert(active.choose_action_for_ai() == BASIC_ATTACK, "AI must choose an affordable action with a living target.")
    var action := BASIC_ATTACK.duplicate(true) as ActionTemplate
    action.target = CombatActions.TARGET.FOE
    action.target_amount = 2
    var phase := BattlePhaseGetActionTargets.new()
    phase.active_unit = active
    phase.selected_action = action
    phase.cargo = {"targets": []}
    phase.on_target_sent(ally)
    assert(phase.cargo.targets.is_empty(), "An ally cannot be selected for a foe-targeting action.")
    phase.on_target_sent(first_foe)
    phase.on_target_sent(first_foe)
    assert(phase.cargo.targets == [first_foe], "Target selection must reject duplicates.")
    phase.on_remove_target(ally)
    assert(phase.cargo.targets == [first_foe], "Removing an unselected target must be harmless.")
    phase.on_remove_target(first_foe)
    assert(phase.cargo.targets.is_empty())
    phase.on_target_sent(first_foe)
    phase.on_target_sent(second_foe)
    assert(phase.selection_complete)
    assert(phase.cargo.targets == [first_foe, second_foe])
    phase.on_clear_targets()
    assert(phase.cargo.targets == [first_foe, second_foe], "Late cancellation must not erase a completed selection.")
    phase.free()
    var cancelled_phase := BattlePhaseGetActionTargets.new()
    cancelled_phase.active_unit = active
    cancelled_phase.selected_action = action
    cancelled_phase.cargo = {"targets": []}
    cancelled_phase.on_back_requested()
    assert(cancelled_phase.selection_complete and cancelled_phase.selection_cancelled)
    assert(cancelled_phase.cargo.targets.is_empty())
    cancelled_phase.free()
    var partial_phase := BattlePhaseGetActionTargets.new()
    partial_phase.active_unit = active
    partial_phase.selected_action = action
    partial_phase.cargo = {"targets": [first_foe]}
    partial_phase.on_back_requested()
    assert(partial_phase.cargo.targets.is_empty() and not partial_phase.selection_complete)
    partial_phase.on_back_requested()
    assert(partial_phase.selection_complete and partial_phase.selection_cancelled)
    partial_phase.free()
    first_foe.get_stat(CombatStats.STATS.Health).decrease_current_flat(10.0)
    second_foe.get_stat(CombatStats.STATS.Health).decrease_current_flat(10.0)
    assert(active.choose_action_for_ai() == null, "AI must skip when no action has a living valid target.")
    BattleController.ally_unit_holder = old_allies
    BattleController.foe_unit_holder = old_foes
    await free_node(battlefield)


## Checks immutable target cursor using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_immutable_target_cursor() -> void:
    var controller := BattlePhaseController.new()
    var first := BattleUnit.new()
    var second := BattleUnit.new()
    var supplied: Array = [first, second]
    controller.begin_target_processing(supplied)
    supplied.clear()
    assert(
        controller.original_targets == [first, second],
        "Phase processing must retain an immutable snapshot of selected targets.",
    )
    assert(controller.targets == [first, second] and controller.target_cursor == 0)
    assert(controller.advance_target())
    assert(controller.targets == [second] and controller.target_cursor == 1)
    assert(controller.original_targets == [first, second])
    assert(not controller.advance_target())
    controller.clear_action_targets()
    assert(controller.targets.is_empty() and controller.original_targets == [first, second])
    controller.clear_action_targets(true)
    assert(controller.original_targets.is_empty())
    first.free()
    second.free()
    controller.free()


## Verifies that revisiting a phase cannot retain callbacks carrying stale cargo.
func _test_phase_exit_handoff_is_one_shot() -> void:
    var controller := BattlePhaseController.new()
    var first := BattlePhase.new()
    var second := BattlePhase.new()
    controller.known_phases = {
        Combat.BATTLE_STATES.SELECT_PARTICIPANTS: first,
        Combat.BATTLE_STATES.INITIALIZE_BATTLEFIELD: second,
    }
    controller.current_phase = Combat.BATTLE_STATES.SELECT_PARTICIPANTS
    controller.previous_phase = Combat.BATTLE_STATES.SELECT_PARTICIPANTS

    controller.change_phase(Combat.BATTLE_STATES.INITIALIZE_BATTLEFIELD, {"visit": 1})
    assert(first.exited.get_connections().size() == 1)
    first.exited.emit()
    assert(first.exited.get_connections().is_empty(), "Exit handoffs must disconnect after firing.")

    controller.change_phase(Combat.BATTLE_STATES.SELECT_PARTICIPANTS, {"visit": 2})
    assert(second.exited.get_connections().size() == 1)
    second.exited.emit()
    assert(second.exited.get_connections().is_empty())

    controller.change_phase(Combat.BATTLE_STATES.INITIALIZE_BATTLEFIELD, {"visit": 3})
    assert(
        first.exited.get_connections().size() == 1,
        "Revisiting a phase must install exactly one exit handoff.",
    )
    first.exited.emit()
    assert(second.cargo.visit == 3, "The destination must receive only the newest transition cargo.")
    first.free()
    second.free()
    controller.free()


## Checks round presentation correlation using test objects and assertions. A failed assertion
## identifies behavior that no longer meets the test’s expectation.
func _test_round_presentation_correlation() -> void:
    var phase := BattlePhaseRoundStart.new()
    phase.request_id = &"round:test:2"
    assert(not phase.is_matching_completion(&"round:test:1"), "A stale round acknowledgement must be ignored.")
    assert(phase.is_matching_completion(&"round:test:2"))
    phase.completed = true
    assert(not phase.is_matching_completion(&"round:test:2"), "A duplicate or late acknowledgement must be ignored.")
    phase.completed = false
    phase.request_id = &""
    assert(not phase.is_matching_completion(&""), "An uninitialized request cannot complete a round.")
    phase.free()


## Checks headless turn order using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_headless_turn_order() -> void:
    var turn_controller := DebugTurnController.new()
    var first := BattleUnit.new()
    var first_defeated := BattleUnit.new()
    var survivor := BattleUnit.new()
    var last_defeated := BattleUnit.new()
    var last := BattleUnit.new()
    turn_controller.turn_order = [first, first_defeated, survivor, last_defeated, last]
    var removed_indices: Array[int] = (
        turn_controller
        . update_turn_order_on_unit_defeat(
            [first_defeated, last_defeated],
        )
    )
    assert(removed_indices == [3, 1], "Presentation removals must keep safe descending indices.")
    assert(turn_controller.turn_order == [first, survivor, last])
    turn_controller.set_next_unit()
    turn_controller.set_next_unit()
    turn_controller.set_next_unit()
    turn_controller.set_next_unit()
    assert(turn_controller.turn_order.is_empty(), "Advancing an empty turn order must be harmless.")
    first.free()
    first_defeated.free()
    survivor.free()
    last_defeated.free()
    last.free()
    turn_controller.free()
