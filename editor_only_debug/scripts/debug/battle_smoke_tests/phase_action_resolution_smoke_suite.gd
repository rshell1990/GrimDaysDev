extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"


## Runs the phase action resolution smoke checks. Creates or uses test objects and stops on failed
## assertions.
func run() -> void:
    var configured_resolver_phase: BattlePhase = BattleController.state_manager.known_phases.get(
        Combat.BATTLE_STATES.RESOLVE_ACTION
    )
    assert(
        configured_resolver_phase is BattlePhaseResolveAction,
        "The real phase controller must contain the deterministic resolver handoff.",
    )
    var target_phase: BattlePhase = BattleController.state_manager.known_phases.get(
        Combat.BATTLE_STATES.SET_COMBAT_TARGETS
    )
    assert(target_phase.default_next_phase == Combat.BATTLE_STATES.RESOLVE_ACTION)

    var arena := Node.new()
    var allies := Node.new()
    var foes := Node.new()
    arena.add_child(allies)
    arena.add_child(foes)
    add_child(arena)
    var actor := BattleUnit.create(CELINE_TEMPLATE)
    var miss_target := BattleUnit.create(CELINE_TEMPLATE)
    var hit_target := BattleUnit.create(CELINE_TEMPLATE)
    allies.add_child(actor)
    foes.add_child(miss_target)
    foes.add_child(hit_target)
    actor.team_id = &"allies"
    miss_target.team_id = &"foes"
    hit_target.team_id = &"foes"
    actor.randomizer.set_seed(100)
    miss_target.randomizer.set_seed(200)
    hit_target.randomizer.set_seed(300)

    var rank := RankTemplate.new()
    rank.id = &"phase_resolver_rank"
    rank.level = 1
    rank.cost = {CombatStats.STATS.Energy: 3}
    rank.cooldown_turns = 1
    rank.effects = BASIC_ATTACK.get_rank_template(1).effects
    var ranks := RanksTemplate.new()
    ranks.id = &"phase_resolver_ranks"
    ranks.all = [rank]
    var action := ActionTemplate.new()
    action.id = &"phase_resolver_action"
    action.display_name = "Phase Resolver Action"
    action.ranks = ranks
    action.target = CombatActions.TARGET.FOE
    action.target_amount = 2
    assert(actor.learn_action(action))

    _set_override(actor, CombatStats.STATS.Energy, 10.0, &"phase_energy")
    _set_override(actor, CombatStats.STATS.Accuracy, 100.0, &"phase_accuracy")
    _set_override(actor, CombatStats.STATS.CriticalStrike, 0.0, &"phase_critical")
    _set_override(actor, CombatStats.STATS.PhysicalDamage, 10.0, &"phase_damage")
    _set_override(miss_target, CombatStats.STATS.Evasion, 100.0, &"phase_miss_evasion")
    _set_override(miss_target, CombatStats.STATS.LuckyEvasion, 0.0, &"phase_miss_lucky")
    _set_override(hit_target, CombatStats.STATS.Evasion, 0.0, &"phase_hit_evasion")
    _set_override(hit_target, CombatStats.STATS.LuckyEvasion, 0.0, &"phase_hit_lucky")
    _set_override(hit_target, CombatStats.STATS.PhysicalResistance, 0.0, &"phase_resistance")

    var previous_result = BattleController.current_battle_result
    var result := BattleResult.new()
    result.encounter_id = &"phase_resolver_test"
    result.battle_seed = 100
    result.rounds = 1
    result.turns = 1
    BattleController.current_battle_result = result
    var controller := BattlePhaseController.new()
    add_child(controller)
    controller.active_unit = actor
    controller.selected_action = action
    controller.begin_target_processing([miss_target, hit_target])
    var expected_rng := RandomNumberGenerator.new()
    expected_rng.state = actor.randomizer.random_number_generator.state
    var expected_damage := roundf(10.0 * expected_rng.randf_range(0.85, 1.15))
    var old_hit_health: float = hit_target.get_stat(CombatStats.STATS.Health).Current
    var resolution: BattleActionResolution = await controller.resolve_current_action()

    assert(resolution.success, resolution.error)
    assert(resolution.get_events(BattleCombatEvent.TYPE.MISS).size() == 1)
    assert(resolution.get_events(BattleCombatEvent.TYPE.HIT).size() == 1)
    assert(resolution.get_events(BattleCombatEvent.TYPE.DAMAGE).size() == 1)
    assert(
        is_equal_approx(
            hit_target.get_stat(CombatStats.STATS.Health).Current,
            old_hit_health - expected_damage,
        )
    )
    assert(is_equal_approx(actor.get_stat(CombatStats.STATS.Energy).Current, 7.0))
    assert(actor.get_action_cooldown(action) == 2, "One multi-target action pays one cost and cooldown.")
    assert(result.combat_events == resolution.events)

    BattleController.current_battle_result = previous_result
    await free_node(controller)
    await free_node(arena)
    await _test_real_phase_victory()
    await _test_real_phase_defeat()


## Drives the configured phase state machine through a deterministic one-turn
## victory without displays, cameras, or player input.
func _test_real_phase_victory() -> void:
    BattleController.cleanup_battle()
    BattleController.clear_presentation_adapter()
    BattleController.state_manager.current_phase = Combat.BATTLE_STATES.SELECT_PARTICIPANTS
    BattleController.state_manager.previous_phase = Combat.BATTLE_STATES.SELECT_PARTICIPANTS
    BattleController.begin_battle_session(&"phase_driven_victory", 4242, {"source": "smoke"})
    BattleController.init_battlefield([CELINE_TEMPLATE], [CELINE_TEMPLATE])
    var ally: BattleUnit = BattleController.ally_unit_holder.get_child(0)
    var foe: BattleUnit = BattleController.foe_unit_holder.get_child(0)
    ally.player_controlled = false
    _set_override(ally, CombatStats.STATS.Health, 100.0, &"phase_battle_ally_health")
    _set_override(ally, CombatStats.STATS.Swiftness, 100.0, &"phase_battle_ally_speed")
    _set_override(ally, CombatStats.STATS.Accuracy, 100.0, &"phase_battle_accuracy")
    _set_override(ally, CombatStats.STATS.CriticalStrike, 0.0, &"phase_battle_critical")
    _set_override(ally, CombatStats.STATS.PhysicalDamage, 100.0, &"phase_battle_damage")
    _set_override(foe, CombatStats.STATS.Health, 10.0, &"phase_battle_foe_health")
    _set_override(foe, CombatStats.STATS.Swiftness, 1.0, &"phase_battle_foe_speed")
    _set_override(foe, CombatStats.STATS.Evasion, 0.0, &"phase_battle_evasion")
    _set_override(foe, CombatStats.STATS.LuckyEvasion, 0.0, &"phase_battle_lucky_evasion")
    _set_override(foe, CombatStats.STATS.PhysicalResistance, 0.0, &"phase_battle_resistance")

    var emitted: Array[BattleResult] = []
    var collect_result := func(sent_result: BattleResult) -> void: emitted.append(sent_result)
    BattleController.battle_finished.connect(collect_result)
    BattleController.change_phase(Combat.BATTLE_STATES.INITIALIZE_TURN_ORDER)
    for frame in 120:
        if not emitted.is_empty():
            break
        await get_tree().process_frame
    assert(not emitted.is_empty(), "The headless real phase flow must reach a terminal result.")
    var result: BattleResult = emitted[0]
    assert(result.is_victory())
    assert(result.rounds == 1 and result.turns == 1)
    assert(
        (
            (
                result
                . combat_events
                . filter(func(event: BattleCombatEvent) -> bool: return event.type == BattleCombatEvent.TYPE.DAMAGE)
                . size()
            )
            == 1
        )
    )
    assert(
        (
            (
                result
                . combat_events
                . filter(func(event: BattleCombatEvent) -> bool: return event.type == BattleCombatEvent.TYPE.DEFEAT)
                . size()
            )
            == 1
        )
    )
    assert(emitted.size() == 1, "The real phase flow must finalize exactly once.")
    BattleController.battle_finished.disconnect(collect_result)
    BattleController.cleanup_battle()
    BattleController.state_manager.current_phase = Combat.BATTLE_STATES.SELECT_PARTICIPANTS
    BattleController.state_manager.previous_phase = Combat.BATTLE_STATES.SELECT_PARTICIPANTS


## Drives the configured phase state machine through the opposing one-turn
## outcome and verifies that defeat finalizes exactly once.
func _test_real_phase_defeat() -> void:
    BattleController.begin_battle_session(&"phase_driven_defeat", 8484, {"source": "smoke"})
    BattleController.init_battlefield([CELINE_TEMPLATE], [CELINE_TEMPLATE])
    var ally: BattleUnit = BattleController.ally_unit_holder.get_child(0)
    var foe: BattleUnit = BattleController.foe_unit_holder.get_child(0)
    ally.player_controlled = false
    _set_override(ally, CombatStats.STATS.Health, 10.0, &"phase_defeat_ally_health")
    _set_override(ally, CombatStats.STATS.Swiftness, 1.0, &"phase_defeat_ally_speed")
    _set_override(ally, CombatStats.STATS.Evasion, 0.0, &"phase_defeat_ally_evasion")
    _set_override(ally, CombatStats.STATS.LuckyEvasion, 0.0, &"phase_defeat_ally_lucky")
    _set_override(ally, CombatStats.STATS.PhysicalResistance, 0.0, &"phase_defeat_resistance")
    _set_override(foe, CombatStats.STATS.Health, 100.0, &"phase_defeat_foe_health")
    _set_override(foe, CombatStats.STATS.Swiftness, 100.0, &"phase_defeat_foe_speed")
    _set_override(foe, CombatStats.STATS.Accuracy, 100.0, &"phase_defeat_accuracy")
    _set_override(foe, CombatStats.STATS.CriticalStrike, 0.0, &"phase_defeat_critical")
    _set_override(foe, CombatStats.STATS.PhysicalDamage, 100.0, &"phase_defeat_damage")

    var emitted: Array[BattleResult] = []
    var collect_result := func(sent_result: BattleResult) -> void: emitted.append(sent_result)
    BattleController.battle_finished.connect(collect_result)
    BattleController.change_phase(Combat.BATTLE_STATES.INITIALIZE_TURN_ORDER)
    for frame in 120:
        if not emitted.is_empty():
            break
        await get_tree().process_frame
    assert(not emitted.is_empty(), "The real phase flow must reach Defeat without presentation.")
    var result: BattleResult = emitted[0]
    assert(result.is_defeat())
    assert(result.rounds == 1 and result.turns == 1)
    assert(
        (
            (
                result
                . combat_events
                . filter(func(event: BattleCombatEvent) -> bool: return event.type == BattleCombatEvent.TYPE.DAMAGE)
                . size()
            )
            == 1
        )
    )
    assert(
        (
            (
                result
                . combat_events
                . filter(func(event: BattleCombatEvent) -> bool: return event.type == BattleCombatEvent.TYPE.DEFEAT)
                . size()
            )
            == 1
        )
    )
    assert(emitted.size() == 1, "The defeat path must finalize exactly once.")
    BattleController.battle_finished.disconnect(collect_result)
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
                    &"test:phase_action_resolution",
                    stat_type,
                    UnitStatModifier.OPERATION.OVERRIDE,
                    amount,
                )
            )
        )
    )
