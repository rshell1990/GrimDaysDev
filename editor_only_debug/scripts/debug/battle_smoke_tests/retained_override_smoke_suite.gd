# Tests fixed Current values and free compulsory actions through real battle services.
extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/production_flow_smoke_suite.gd"

const FIX_STAT = preload("res://GrimDaysBattle/scripts/Effects/Resources/effect_fix_stat.gd")
const FORCE_ACTION = preload("res://GrimDaysBattle/scripts/Effects/Resources/effect_force_action.gd")


func run() -> void:
    await _test_current_locks()
    await _test_forced_resolution_and_retry()
    await _test_forced_player_turn()
    print("RETAINED_OVERRIDE_SMOKE_SUITE: PASS") # lint:ignore debug-print -- Required test/CLI output.


func _lock(unit: BattleUnit, stat_id: int, value: float, priority: int = 0) -> EffectBase:
    var definition := FIX_STAT.new()
    definition.id = &"fixed_current_test"
    definition.stat = stat_id
    definition.value = value
    definition.priority = priority
    definition.stacking = EffectTemplate.STACKING.MULTIPLE
    var effect := unit.add_effect(unit, unit, definition)
    effect.apply()
    return effect


func _force(unit: BattleUnit, action: ActionTemplate, rank: int = 1, priority: int = 0) -> EffectBase:
    var definition := FORCE_ACTION.new()
    definition.id = &"forced_action_test"
    definition.action = action
    definition.action_rank = rank
    definition.priority = priority
    definition.stacking = EffectTemplate.STACKING.MULTIPLE
    var effect := unit.add_effect(unit, unit, definition)
    effect.apply()
    return effect


func _test_current_locks() -> void:
    var unit := BattleUnit.create(CELINE_TEMPLATE)
    add_child(unit)
    var health := unit.get_stat(CombatStats.STATS.Health)
    health.set_base(100.0)
    health.restore_current(60.5)
    var first := _lock(unit, CombatStats.STATS.Health, 25.25)
    var observed: Array[float] = []
    health.value_changed.connect(func(_stat, _old, value): observed.append(value))
    health.decrease_current_flat(90)
    health.increase_current_flat(90)
    health.restore_current(0)
    assert(health.Current == 25.25 and observed.is_empty())
    health.set_base(200)
    assert(health.Current == 25.25 and health.Max == 200)
    assert(observed.all(func(value): return value == 25.25))
    var second := _lock(unit, CombatStats.STATS.Health, 500, 1)
    var third := _lock(unit, CombatStats.STATS.Health, 7, 1)
    assert(health.Current == 7)
    third.remove()
    assert(health.Current == 500, "Fixed Current may intentionally exceed Max.")
    second.remove()
    assert(health.Current == 25.25)
    first.remove()
    assert(health.Current == 121, "Underlying fill ratio follows capacity changes; blocked damage is discarded.")
    var encumbrance := unit.get_stat(CombatStats.STATS.Encumberance)
    var scalar := _lock(unit, CombatStats.STATS.Encumberance, 13)
    encumbrance.set_base(199)
    assert(encumbrance.Current == 13)
    scalar.remove()
    var expiring := _lock(unit, CombatStats.STATS.Health, 10)
    expiring.lifetime = EffectTemplate.LIFETIME.ROUNDS
    expiring.duration = 1
    expiring.on_round_end()
    assert(expiring.removed and health.current_locks.is_empty())
    unit.queue_free()
    await unit.tree_exited


func _costly_action() -> ActionTemplate:
    var action := BASIC_ATTACK.duplicate(true) as ActionTemplate
    action.id = &"forced_unowned_action"
    action.target = CombatActions.TARGET.SELF
    action.ranks = RanksTemplate.new()
    for index in 2:
        var rank := RankTemplate.new()
        rank.level = index + 1
        rank.cost = {CombatStats.STATS.Energy: 9999}
        rank.cooldown_turns = 8
        rank.effects = EffectTemplates.new()
        action.ranks.all.append(rank)
    return action


func _test_forced_resolution_and_retry() -> void:
    var unit := BattleUnit.create(CELINE_TEMPLATE)
    add_child(unit)
    unit.player_controlled = true
    var action := _costly_action()
    var health := unit.get_stat(CombatStats.STATS.Health)
    var before := health.Current
    var lock := _lock(unit, CombatStats.STATS.Health, 31)
    var effect := _force(unit, action, 2)
    var competing := _force(unit, BASIC_ATTACK, 1, -1)
    assert(unit.get_forced_action_effect() == effect)
    assert(unit.get_action_rank(action) == 2 and not unit.is_action_learned(action))
    var player_override := RefCounted.new()
    unit.add_control_override(player_override, true)
    assert(not unit.player_controlled, "A mandate retains AI control even over a later player override.")
    unit.remove_control_override(player_override)
    assert(not unit.player_controlled)
    unit._action_cooldowns[action.id] = 7
    var energy := unit.get_stat(CombatStats.STATS.Energy)
    energy.restore_current(0)
    var resolver := BattleActionResolver.new()
    add_child(resolver)
    var request := BattleActionRequest.new(&"forced", unit, action, [unit])
    assert(request.free_action and request.get_execution_rank() == 2)
    var result: BattleActionResolution = await resolver.resolve(request)
    assert(result.success, result.error)
    assert(result.get_events(BattleCombatEvent.TYPE.COST_PAID).is_empty())
    assert(energy.Current == 0 and unit._action_cooldowns[action.id] == 7)
    var checkpoint := BattleRetryCheckpoint.new()
    checkpoint.capture([unit])
    lock.remove()
    effect.remove()
    competing.remove()
    await get_tree().process_frame
    assert(health.Current == before and unit.get_forced_action_effect() == null)
    assert(unit.player_controlled)
    assert(checkpoint.restore())
    assert(health.Current == 31 and unit.get_forced_action_effect().definition.action == action)
    health.decrease_current_flat(50)
    assert(health.Current == 31)
    var restored := unit.get_forced_action_effect()
    assert(restored.definition.action_rank == 2)
    unit.effect_manager.remove_effects_from_source(restored.source_id)
    assert(unit.get_forced_action_effect() == null and health.current_locks.is_empty())
    assert(not unit.is_action_learned(action))
    var stale: BattleActionResolution = await resolver.resolve(request)
    assert(not stale.success)
    var expiring := _force(unit, action)
    expiring.lifetime = EffectTemplate.LIFETIME.ROUNDS
    expiring.duration = 1
    assert(not unit.player_controlled)
    expiring.on_round_end()
    assert(unit.player_controlled and unit.get_forced_action_effect() == null)
    resolver.queue_free()
    unit.queue_free()
    await unit.tree_exited


func _test_forced_player_turn() -> void:
    var fixture := _fixture([HARLOK], CELINE_TEMPLATE, false)
    var flow: BattleEncounterFlow = fixture.scene.flow
    await _wait_for_action(flow)
    var actor: BattleUnit = fixture.ally
    var turn_before := flow.turn_id
    var results: Array[BattleActionResolution] = []
    flow.action_completed.connect(func(result): results.append(result))
    var action := _costly_action()
    _force(actor, action, 2)
    assert(not flow.choose_command(turn_before, CombatActions.COMMAND.DEFEND))
    for frame in 1200:
        if not results.is_empty():
            break
        await get_tree().process_frame
    assert(not results.is_empty(), "Mandate must replace the pending player choice.")
    assert(results[0].success and results[0].get_events(BattleCombatEvent.TYPE.COST_PAID).is_empty())
    assert(not actor.is_action_learned(action))
    fixture.scene.cancel_session()
    fixture.scene.queue_free()
    fixture.party.queue_free()
    await fixture.party.tree_exited
