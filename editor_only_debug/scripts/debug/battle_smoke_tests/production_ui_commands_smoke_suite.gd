extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/production_flow_smoke_suite.gd"
## Regression coverage of ordinary Defend effects and restored production controls.


func run() -> void:
    await _test_wheel_animation_gate()
    await _test_defend_effect()
    await _test_wheel_and_wait()
    await _test_escape()
    await _test_failed_escape()
    await _test_missing_round_display()


func _test_defend_effect() -> void:
    var unit := BattleUnit.create(CELINE_TEMPLATE)
    add_child(unit)
    var physical := unit.get_stat(CombatStats.STATS.PhysicalResistance)
    var magic := unit.get_stat(CombatStats.STATS.MagicResistance)
    for example in [[20.0, 55.0], [70.0, 90.0], [85.0, 90.0], [90.0, 90.0], [91.0, 91.0]]:
        _override(unit, CombatStats.STATS.PhysicalResistance, example[0])
        _override(unit, CombatStats.STATS.MagicResistance, example[0])
        assert(BattleDefend.can_defend(unit) == (example[0] < 90))
        await BattleDefend.apply(unit, func(): return true)
        assert(is_equal_approx(physical.Current, example[1]))
        assert(is_equal_approx(magic.Current, example[1]))
        assert(unit.effect_manager.get_effects_from_source(&"battle_command:defend").size() == 2)
        await BattleDefend.apply(unit, func(): return true)
        assert(unit.effect_manager.get_effects_from_source(&"battle_command:defend").size() == 2)
        unit.effect_manager.advance_round()
        assert(is_equal_approx(physical.Current, example[0]))
        await get_tree().process_frame
    _override(unit, CombatStats.STATS.PhysicalResistance, 20)
    await BattleDefend.apply(unit, func(): return true)
    _override(unit, CombatStats.STATS.PhysicalResistance, 85)
    assert(physical.Current == 90)
    _override(unit, CombatStats.STATS.PhysicalResistance, 91)
    assert(physical.Current == 91)
    _override(unit, CombatStats.STATS.PhysicalResistance, 40)
    assert(physical.Current == 75)
    unit.effect_manager.remove_battle_scoped_effects()
    assert(physical.Current == 40)
    # A multiplication applies before capped points; removing the source restores it exactly.
    physical.remove_modifiers_from_source(&"test:production_flow")
    physical.set_base(20)
    physical.add_modifier(
        UnitStatModifier.create(&"double", &"test", physical.id, UnitStatModifier.OPERATION.MULTIPLY, 2)
    )
    await BattleDefend.apply(unit, func(): return true)
    assert(physical.Current == 75)
    unit.effect_manager.remove_battle_scoped_effects()
    assert(physical.Current == 40)
    await free_node(unit)


func _test_wheel_and_wait() -> void:
    var fixture := _fixture([HARLOK])
    var scene: BattleEncounterScene = fixture.scene
    var actor: BattleUnit = fixture.ally
    var foe: BattleUnit = scene.coordinator.roster.get_foes()[0]
    foe.player_controlled = true
    actor._action_cooldowns[&"wait_test"] = 3
    for _frame in 64:
        if scene.get_node("Interface/BattleHUD/RoundStart").visible:
            break
        await get_tree().process_frame
    assert(scene.get_node("Interface/BattleHUD/RoundStart").visible)
    assert(scene.coordinator.current_result.turns == 0, "Announcement must precede turn-start processing.")
    await _wait_for_action(scene.flow)
    assert(not scene.get_node("Interface/BattleHUD/RoundStart").visible)
    var cooldown_before: int = actor._action_cooldowns[&"wait_test"]
    var hud: BattleProductionHUD = scene.get_node("Interface/BattleHUD")
    var wheel: BattleActionWheel = scene.stage.get_unit_display(actor).get_node("UI Elements/Action Wheel")
    assert(hud.active.visible and hud.party.visible and wheel.visible)
    assert(not scene.get_node("Interface/ActionMenu/Content/Status").visible)
    _override(actor, CombatStats.STATS.PhysicalResistance, 90)
    _override(actor, CombatStats.STATS.MagicResistance, 91)
    await get_tree().process_frame
    assert(wheel.get_node("Defend").disabled)
    assert(not scene.flow.choose_command(scene.flow.turn_id, CombatActions.COMMAND.DEFEND))
    _override(actor, CombatStats.STATS.MagicResistance, 20)
    await get_tree().process_frame
    assert(not wheel.get_node("Defend").disabled)
    var skill := BASIC_ATTACK.duplicate(true) as ActionTemplate
    skill.id = &"ui_skill_probe"
    skill.description = "A skill description for tooltip verification."
    var skill_rank := RankTemplate.new()
    skill_rank.effects = BASIC_ATTACK.get_rank_template(1).effects
    skill_rank.cost = {CombatStats.STATS.Energy: 3, CombatStats.STATS.Mana: 2}
    skill.ranks = RanksTemplate.new()
    skill.ranks.all = [skill_rank]
    assert(actor.learn_action(skill))
    var initial_turns: int = scene.coordinator.current_result.turns
    assert(scene.flow.choose_command(scene.flow.turn_id, CombatActions.COMMAND.WAIT))
    await _wait_for_action(scene.flow)
    assert(scene.flow.active_unit == foe)
    assert(scene.flow.choose_command(scene.flow.turn_id, CombatActions.COMMAND.DEFEND))
    await _wait_for_action(scene.flow)
    assert(scene.flow.active_unit == actor)
    assert(scene.coordinator.current_result.turns == initial_turns + 1)
    assert(actor._action_cooldowns[&"wait_test"] == cooldown_before)
    assert(not scene.flow.can_choose_command(CombatActions.COMMAND.WAIT))
    wheel.get_node("Skills").pressed.emit()
    var skill_button: Button = wheel.skills.get_child(1)
    assert(skill_button.tooltip_text == skill.description)
    assert(skill_button.get_child(0).get_child(-1).get_child_count() == 4)
    wheel.get_node("Items").pressed.emit()
    assert(wheel.items.visible and wheel.items.get_child_count() == 9)
    assert(scene.flow.choose_action(scene.flow.turn_id, actor.get_basic_action()))
    assert(hud.active.visible and hud.party.visible)
    assert(scene.flow.state == BattleEncounterFlow.STATE.TARGETS)
    scene.flow.cancel_selection()
    assert(wheel.visible)
    scene.cancel_session()
    assert(not hud.active.visible)
    await free_node(scene)
    await free_node(fixture.party)


func _test_escape() -> void:
    var fixture := _fixture([HARLOK])
    var scene: BattleEncounterScene = fixture.scene
    var actor: BattleUnit = fixture.ally
    _override(actor, CombatStats.STATS.Evasion, 100)
    await _wait_for_action(scene.flow)
    scene.flow.flee_allowed = false
    assert(not scene.flow.choose_command(scene.flow.turn_id, CombatActions.COMMAND.FLEE))
    scene.flow.flee_allowed = true
    assert(scene.flow.choose_command(scene.flow.turn_id, CombatActions.COMMAND.FLEE))
    var deadline := Time.get_ticks_msec() + 5000
    while scene.flow.state != BattleEncounterFlow.STATE.STOPPED and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    var result := scene.coordinator.current_result
    assert(result.is_defeat())
    assert(actor in result.escaped_allies and actor not in result.defeated_units)
    assert(actor.is_active and not scene.coordinator.roster.is_present(actor))
    assert(result.ally_snapshots[0].escaped)
    assert(
        not CombatActions.valid_target(
            scene.coordinator.roster.get_foes()[0].get_basic_action(), scene.coordinator.roster.get_foes()[0], actor
        )
    )
    scene.coordinator.cleanup(scene.coordinator.session_id)
    assert(scene.coordinator.roster.escaped.is_empty())
    await free_node(scene)
    await free_node(fixture.party)


func _test_failed_escape() -> void:
    var fixture := _fixture([HARLOK])
    var scene: BattleEncounterScene = fixture.scene
    var actor: BattleUnit = fixture.ally
    var foe: BattleUnit = scene.coordinator.roster.get_foes()[0]
    foe.player_controlled = true
    _override(actor, CombatStats.STATS.Luck, 0)
    await _wait_for_action(scene.flow)
    var probe := RandomNumberGenerator.new()
    for seed_value in range(1, 100):
        probe.seed = seed_value
        if probe.randf_range(0.0, 100.0) >= 35.0:
            actor.randomizer.set_seed(seed_value)
            break
    var old_turn := scene.flow.turn_id
    assert(scene.flow.choose_command(old_turn, CombatActions.COMMAND.FLEE))
    await _wait_for_action(scene.flow)
    assert(scene.flow.fleeing and scene.flow.active_unit == foe)
    assert(scene.coordinator.roster.is_present(actor) and actor.randomizer.fails == 1)
    assert(not scene.flow.choose_action(old_turn, actor.get_basic_action()))
    scene.cancel_session()
    await free_node(scene)
    await free_node(fixture.party)


func _test_missing_round_display() -> void:
    var fixture := _fixture([HARLOK], CELINE_TEMPLATE, false)
    await _wait_for_action(fixture.scene.flow)
    assert(fixture.scene.coordinator.current_result.rounds == 1)
    fixture.scene.cancel_session()
    await free_node(fixture.scene)
    await free_node(fixture.party)


func _wait_for_action(flow: BattleEncounterFlow) -> void:
    await super._wait_for_action(flow)
    var wheel: BattleActionWheel = flow.stage.get_unit_display(flow.active_unit).get_node("UI Elements/Action Wheel")
    var deadline := Time.get_ticks_msec() + 5000
    while not wheel._accepting and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    assert(wheel._accepting)


func _test_wheel_animation_gate() -> void:
    var fixture := _fixture([HARLOK])
    var scene: BattleEncounterScene = fixture.scene
    var actor: BattleUnit = fixture.ally
    await super._wait_for_action(scene.flow)
    var wheel: BattleActionWheel = scene.stage.get_unit_display(actor).get_node("UI Elements/Action Wheel")
    assert(wheel.visible and not wheel._accepting)
    assert(wheel.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_DISABLED)
    wheel.get_node("Items").pressed.emit()
    assert(not wheel.panel.visible, "Opening wheel must reject input.")
    await _wait_for_action(scene.flow)
    assert(wheel.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_ENABLED)
    # Commit a command and check it has not granted effects while the wheel closes.
    wheel.get_node("Defend").pressed.emit()
    assert(wheel.visible and wheel._closing)
    await get_tree().process_frame
    assert(actor.effect_manager.get_effects_from_source(&"battle_command:defend").is_empty())
    assert(scene.flow.active_unit == actor)
    var deadline := Time.get_ticks_msec() + 5000
    while wheel.visible and Time.get_ticks_msec() < deadline:
        assert(actor.effect_manager.get_effects_from_source(&"battle_command:defend").is_empty())
        await get_tree().process_frame
    assert(not wheel.visible)
    scene.cancel_session()
    await free_node(scene)
    await free_node(fixture.party)
    # Stopping during reverse animation must discard the pending command.
    fixture = _fixture([HARLOK])
    scene = fixture.scene
    actor = fixture.ally
    await _wait_for_action(scene.flow)
    assert(scene.flow.choose_command(scene.flow.turn_id, CombatActions.COMMAND.DEFEND))
    scene.cancel_session()
    await get_tree().create_timer(0.6).timeout
    assert(actor.effect_manager.get_effects_from_source(&"battle_command:defend").is_empty())
    await free_node(scene)
    await free_node(fixture.party)
