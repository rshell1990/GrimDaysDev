extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/production_flow_smoke_suite.gd"
## Pending-turn semantics, a real player action and the authored Control grant.

const DELAY_SCENE := preload("res://GrimDaysBattle/scenes/battle/effects/effect_delay_turn.tscn")
## Authored five-rank Control definition: 5% additional Lucidity capacity per rank.
const CONTROL_NODE: BattleSkillPassiveNode = preload(
    "res://GrimDaysBattle/resources/skill_trees/celine/troubled_youth/tier 3/control_node.tres"
)


## Runs pending-order, production delay-action and authored Control-rank checks.
func run() -> void:
    await _test_pending_order()
    await _test_delay_action()
    await _test_control_lucidity()


## Checks delay swaps only eligible pending units and does not carry into the next round.
func _test_pending_order() -> void:
    var units: Array[BattleUnit] = []
    for index in 4:
        var unit := BattleUnit.create(CELINE_TEMPLATE)
        add_child(unit)
        units.append(unit)
    var order := BattleTurnOrder.new()
    order.begin_round(units)
    assert(order.mark_turn_started() and not order.mark_turn_started())
    assert(not order.delay_pending(units[0]))
    assert(order.delay_pending(units[1]))
    assert(order.get_units() == [units[0], units[2], units[1], units[3]])
    assert(not order.delay_pending(units[3]))
    units[2].get_stat(CombatStats.STATS.Health).restore_current(0)
    assert(not order.delay_pending(units[2]))
    assert(order.delay_pending(units[1]))
    assert(order.get_units() == [units[0], units[2], units[3], units[1]])
    order.advance()
    assert(not order.delay_pending(units[0]), "Already-acted units are not reinserted.")
    assert(order.get_active_unit() == units[3])
    order.begin_round(units)
    assert(order.get_units() == [units[0], units[1], units[3]], "Delay does not carry to the next round.")
    order.clear()
    assert(not order.delay_pending(units[1]))
    for unit in units:
        await free_node(unit)


## Checks a real player action delays one foe, emits one attributed event and preserves turn
## counters and stale-session guards.
func _test_delay_action() -> void:
    var fixture := _fixture([HARLOK, HARLOK, HARLOK])
    var scene: BattleEncounterScene = fixture.scene
    var ally: BattleUnit = fixture.ally
    var foes := scene.coordinator.roster.get_foes()
    for foe in foes:
        foe.player_controlled = true  # Pause each actual turn for deterministic inspection.
    var effect := EffectDelayTurnTemplate.new()
    effect.id = &"delay_test"
    effect.target = CombatActions.TARGET.FOE
    effect.kind = CombatEffects.KIND.ONCE
    effect.trigger = CombatEffects.TRIGGER.DAMAGED
    effect.template_scene = DELAY_SCENE
    var action := BASIC_ATTACK.duplicate() as ActionTemplate
    action.id = &"pending_delay_action"
    action.always_hits = true
    action.ranks = RanksTemplate.new()
    var rank := RankTemplate.new()
    rank.effects = EffectTemplates.new()
    rank.effects.all = [effect]
    action.ranks.all = [rank]
    assert(ally.learn_action(action))
    var completed: Array[BattleActionResolution] = []
    scene.flow.action_completed.connect(func(result): completed.append(result))
    await _wait_for_action(scene.flow)
    assert(scene.flow.active_unit == ally)
    assert(scene.flow.choose_action(scene.flow.turn_id, action))
    scene.stage.get_unit_display(foes[0]).targeting_controller.add_unit(foes[0])
    await _wait_for_action(scene.flow)
    assert(completed.size() == 1 and completed[0].success)
    var events: Array = completed[0].events.filter(func(event): return event.type == BattleCombatEvent.TYPE.TURN_DELAY)
    assert(events.size() == 1 and events[0].actor == ally and events[0].target == foes[0])
    assert(scene.flow.active_unit == foes[1])
    assert(scene.coordinator.current_result.turns == 2 and scene.coordinator.current_result.rounds == 1)
    assert(not scene.coordinator.roster.delay_pending_turn(foes[1]), "Counters cannot delay an already-started turn.")
    for expected in [foes[0], foes[2], ally]:
        assert(scene.flow.choose_command(scene.flow.turn_id, CombatActions.COMMAND.DEFEND))
        await _wait_for_action(scene.flow)
        assert(scene.flow.active_unit == expected)
    assert(scene.coordinator.current_result.turns == 5 and scene.coordinator.current_result.rounds == 2)
    var stale := scene.coordinator.roster.turn_delay_request
    scene.coordinator.cleanup(scene.coordinator.session_id)
    assert(not stale.call(ally))
    assert(not scene.coordinator.roster.delay_pending_turn(ally))
    await free_node(scene)
    await free_node(fixture.party)


## Purchases all five authored Control ranks and checks their 5%-per-rank Lucidity capacity
## bonuses, fullness preservation and source-owned removal.
func _test_control_lucidity() -> void:
    var unit := BattleUnit.create(CELINE_TEMPLATE)
    add_child(unit)
    var lucidity := unit.get_stat(CombatStats.STATS.Lucidity)
    assert(lucidity and lucidity.Max > 0)
    var maximum: float = lucidity.Max
    lucidity.restore_current(maximum * 0.5)
    var tier := BattleSkillTier.new()
    tier.column = 2
    tier.minimum_stats[CombatStats.STATS.Level] = 3
    var tree := BattleSkillTree.new()
    tree.id = &"troubled_youth"
    tree.tiers = [tier]
    tier.nodes = [CONTROL_NODE]
    var collection := BattleSkillTreeCollection.new()
    collection.trees = [tree]
    var ledger := BattleSkillInvestment.new()
    assert(ledger.configure(collection).is_empty())
    var grants := BattleSkillGrantReconciler.new()
    var authored_grant := CONTROL_NODE.passive_stat_modifiers[0]
    assert(authored_grant.stat == CombatStats.STATS.Lucidity)
    assert(authored_grant.amounts_by_rank.size() == CONTROL_NODE.maximum_rank)
    for rank in range(1, CONTROL_NODE.maximum_rank + 1):
        assert(
            (
                ledger
                . purchase(
                    {CONTROL_NODE.id: 1}, CONTROL_NODE.maximum_rank, {CombatStats.STATS.Level: 3}, ledger.revision
                )
                . is_empty()
            )
        )
        assert(grants.reconcile(unit, ledger, {CombatStats.STATS.Level: 3}).is_empty())
        var expected_maximum: float = maximum * (1.0 + authored_grant.amounts_by_rank[rank - 1])
        assert(is_equal_approx(lucidity.Max, expected_maximum))
        assert(is_equal_approx(lucidity.ratio, 0.5), "Control preserves pool fullness, not a free refill.")
    lucidity.restore_current(0)
    assert(grants.clear())
    assert(is_equal_approx(lucidity.Max, maximum) and lucidity.Current == 0)
    await free_node(unit)
