extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"


## Runs the round effect defeat phase smoke checks. Creates or uses test objects and stops on failed
## assertions.
func run() -> void:
    BattleController.cleanup_battle()
    BattleController.clear_presentation_adapter()
    BattleController.state_manager.current_phase = Combat.BATTLE_STATES.SELECT_PARTICIPANTS
    BattleController.state_manager.previous_phase = Combat.BATTLE_STATES.SELECT_PARTICIPANTS
    BattleController.begin_battle_session(&"round_effect_defeat", 4545, {"source": "smoke"})
    BattleController.init_battlefield([CELINE_TEMPLATE], [CELINE_TEMPLATE])
    var ally: BattleUnit = BattleController.ally_unit_holder.get_child(0)
    var foe: BattleUnit = BattleController.foe_unit_holder.get_child(0)
    ally.player_controlled = false
    foe.player_controlled = false
    _set_override(ally, CombatStats.STATS.Health, 10.0, &"round_defeat_ally_health")
    _set_override(ally, CombatStats.STATS.Swiftness, 100.0, &"round_defeat_ally_speed")
    _set_override(ally, CombatStats.STATS.PhysicalDamage, 0.0, &"round_defeat_ally_damage")
    _set_override(foe, CombatStats.STATS.Swiftness, 50.0, &"round_defeat_foe_speed")
    _set_override(foe, CombatStats.STATS.PhysicalDamage, 0.0, &"round_defeat_foe_damage")
    _set_override(foe, CombatStats.STATS.MagicDamage, 100.0, &"round_defeat_effect_power")

    var damage_template := make_scaled_template(
        &"round_effect_lethal_damage",
        CombatStats.STATS.MagicDamage,
        -0.25,
        CombatDamage.TYPE.True,
    )
    damage_template.duration = 2
    damage_template.lifetime = EffectTemplate.LIFETIME.ROUNDS
    damage_template.kind = CombatEffects.KIND.REPEAT
    damage_template.trigger = CombatEffects.TRIGGER.ROUND_OVER
    ally.effect_manager.add_effect(foe, ally, damage_template)

    var emitted: Array[BattleResult] = []
    var collect_result := func(sent_result: BattleResult) -> void: emitted.append(sent_result)
    var round_boundaries: Array[int] = [0]
    var collect_round_end := func(_request_id: StringName) -> void: round_boundaries[0] += 1
    BattleController.battle_finished.connect(collect_result)
    SignalBus.tick.connect(collect_round_end)
    BattleController.change_phase(Combat.BATTLE_STATES.INITIALIZE_TURN_ORDER)
    for frame in 240:
        if not emitted.is_empty():
            break
        await get_tree().process_frame

    assert(not emitted.is_empty(), "A lethal round effect must reach a terminal battle phase.")
    var result: BattleResult = emitted[0]
    assert(result.is_defeat())
    assert(result.rounds == 1, "Round-effect defeat must not start a phantom second round.")
    assert(result.turns == 2, "Both normal turns must finish before ROUND_OVER effects resolve.")
    assert(result.defeated_units == [ally])
    assert(ally.last_hit_by == foe, "A periodic defeat must retain its effect source for kill processing.")
    assert(round_boundaries[0] == 0, "Terminal round effects must not advance the round boundary.")
    assert(emitted.size() == 1)

    var check_phase: BattlePhase = BattleController.state_manager.known_phases[
        Combat.BATTLE_STATES.PROCESS_CHECK_FOR_DEFEATED
    ]
    var defeat_cargo: Dictionary = check_phase.cargo
    assert(defeat_cargo.round_end)
    assert(defeat_cargo.defeated == [ally] and defeat_cargo.processed == [ally])
    assert(defeat_cargo.defeat_cursor == 1)

    BattleController.battle_finished.disconnect(collect_result)
    SignalBus.tick.disconnect(collect_round_end)
    BattleController.cleanup_battle()
    BattleController.state_manager.current_phase = Combat.BATTLE_STATES.SELECT_PARTICIPANTS
    BattleController.state_manager.previous_phase = Combat.BATTLE_STATES.SELECT_PARTICIPANTS


## Adds a test-only stat adjustment that replaces the selected stat's value with the supplied
## amount.
func _set_override(
    unit: BattleUnit,
    stat_type: CombatStats.STATS,
    amount: float,
    modifier_id: StringName,
) -> void:
    (
        unit
        . get_stat(stat_type)
        . add_modifier(
            (
                UnitStatModifier
                . create(
                    modifier_id,
                    &"test:round_effect_defeat",
                    stat_type,
                    UnitStatModifier.OPERATION.OVERRIDE,
                    amount,
                )
            )
        )
    )
