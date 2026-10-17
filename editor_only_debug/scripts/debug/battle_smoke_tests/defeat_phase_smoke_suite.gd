extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"


## Runs the defeat phase smoke checks. Creates or uses test objects and stops on failed assertions.
func run() -> void:
    BattleController.cleanup_battle()
    BattleController.clear_presentation_adapter()
    BattleController.state_manager.current_phase = Combat.BATTLE_STATES.SELECT_PARTICIPANTS
    BattleController.state_manager.previous_phase = Combat.BATTLE_STATES.SELECT_PARTICIPANTS
    BattleController.begin_battle_session(&"multi_defeat_cursor", 9898, {"source": "smoke"})
    BattleController.init_battlefield([CELINE_TEMPLATE], [CELINE_TEMPLATE, CELINE_TEMPLATE])
    var actor: BattleUnit = BattleController.ally_unit_holder.get_child(0)
    var first_foe: BattleUnit = BattleController.foe_unit_holder.get_child(0)
    var second_foe: BattleUnit = BattleController.foe_unit_holder.get_child(1)
    actor.player_controlled = false
    actor.default_basic_action_template = _create_multi_target_action()
    _set_override(actor, CombatStats.STATS.Swiftness, 100.0, &"multi_defeat_speed")
    _set_override(actor, CombatStats.STATS.Accuracy, 100.0, &"multi_defeat_accuracy")
    _set_override(actor, CombatStats.STATS.CriticalStrike, 0.0, &"multi_defeat_critical")
    _set_override(actor, CombatStats.STATS.PhysicalDamage, 100.0, &"multi_defeat_damage")
    for foe in [first_foe, second_foe]:
        _set_override(foe, CombatStats.STATS.Health, 10.0, &"multi_defeat_health")
        _set_override(foe, CombatStats.STATS.Swiftness, 1.0, &"multi_defeat_foe_speed")
        _set_override(foe, CombatStats.STATS.Evasion, 0.0, &"multi_defeat_evasion")
        _set_override(foe, CombatStats.STATS.LuckyEvasion, 0.0, &"multi_defeat_lucky")
        _set_override(foe, CombatStats.STATS.PhysicalResistance, 0.0, &"multi_defeat_resistance")

    var emitted: Array[BattleResult] = []
    var collect_result := func(sent_result: BattleResult) -> void: emitted.append(sent_result)
    BattleController.battle_finished.connect(collect_result)
    BattleController.change_phase(Combat.BATTLE_STATES.INITIALIZE_TURN_ORDER)
    for frame in 180:
        if not emitted.is_empty():
            break
        await get_tree().process_frame
    assert(not emitted.is_empty(), "A two-target defeat must reach Victory without presentation.")
    var result: BattleResult = emitted[0]
    assert(result.is_victory() and result.turns == 1 and result.rounds == 1)
    assert(result.defeated_units == [first_foe, second_foe])
    assert(_event_targets(result, BattleCombatEvent.TYPE.DAMAGE) == [first_foe, second_foe])
    assert(_event_targets(result, BattleCombatEvent.TYPE.DEFEAT) == [first_foe, second_foe])

    var check_phase: BattlePhase = BattleController.state_manager.known_phases[
        Combat.BATTLE_STATES.PROCESS_CHECK_FOR_DEFEATED
    ]
    var defeat_cargo: Dictionary = check_phase.cargo
    assert(defeat_cargo.defeated == [first_foe, second_foe])
    assert(defeat_cargo.processed == defeat_cargo.defeated)
    assert(defeat_cargo.defeat_cursor == 2)
    assert(defeat_cargo.turn_order_removed_count == 2)
    assert(emitted.size() == 1)

    BattleController.battle_finished.disconnect(collect_result)
    BattleController.cleanup_battle()
    BattleController.state_manager.current_phase = Combat.BATTLE_STATES.SELECT_PARTICIPANTS
    BattleController.state_manager.previous_phase = Combat.BATTLE_STATES.SELECT_PARTICIPANTS


## Sets [code]rank.id[/code] to [code]&"multi_defeat_rank"[/code]; sets [code]rank.level[/code] to
## [code]1[/code]; sets [code]rank.effects[/code] to
## [code]BASIC_ATTACK.get_rank_template(1).effects[/code]. Returns [code]action[/code].
func _create_multi_target_action() -> ActionTemplate:
    var rank := RankTemplate.new()
    rank.id = &"multi_defeat_rank"
    rank.level = 1
    rank.effects = BASIC_ATTACK.get_rank_template(1).effects
    var ranks := RanksTemplate.new()
    ranks.id = &"multi_defeat_ranks"
    ranks.all = [rank]
    var action := ActionTemplate.new()
    action.id = &"multi_defeat_action"
    action.display_name = "Multi Defeat"
    action.ranks = ranks
    action.target = CombatActions.TARGET.FOES
    action.target_amount = 2
    return action


## Returns the target units from combat events matching the requested event type.
func _event_targets(result: BattleResult, type: BattleCombatEvent.TYPE) -> Array:
    return (
        result
        . combat_events
        . filter(func(event: BattleCombatEvent) -> bool: return event.type == type)
        . map(func(event: BattleCombatEvent) -> BattleUnit: return event.target)
    )


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
                    &"test:defeat_phase",
                    stat_type,
                    UnitStatModifier.OPERATION.OVERRIDE,
                    amount,
                )
            )
        )
    )
