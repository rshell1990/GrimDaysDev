extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/damage_reaction_smoke_suite.gd"
## Hostile selection precedes each actual recipient's first hit, including area
## and chained expansion, and is separate from per-operation damage reactions.


func run() -> void:
    await _test_implicit_area_targets(false)
    await _test_implicit_area_targets(true)
    await _test_friendly_healing()
    await _test_miss_selection()
    await _test_targeted_counter_cycle()
    await _test_cancel_on_selection()


## Checks direct or chained area expansion targets each hostile recipient once before accuracy
## without rewriting the request's selected targets.
func _test_implicit_area_targets(chained: bool) -> void:
    var f := _fixture(2)
    for foe in f.foes:
        _grant(
            foe,
            _resource(
                &"selected", CombatEffects.TRIGGER.TARGETED, CombatActions.TARGET.SELF, -3, CombatStats.STATS.Mana
            )
        )
        _grant(
            foe,
            _resource(&"incoming", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.SELF, -1, CombatStats.STATS.Mana)
        )
    var operations: Array[EffectTemplate] = [
        _resource(&"area_one", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOES, -10),
        _resource(&"area_two", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOES, -10),
    ]
    if chained:
        var chain := EffectTriggerAnotherEffect.new()
        chain.id = &"area_chain"
        chain.target = CombatActions.TARGET.FOE
        chain.trigger = CombatEffects.TRIGGER.DAMAGED
        chain.template_scene = CHAIN_SCENE
        chain.triggers = operations
        operations = [chain]
    var action := _action(f.actor, operations)
    var request := BattleActionRequest.new(&"implicit_area", f.actor, action, [f.foes[0]])
    var result: BattleActionResolution = await f.resolver.resolve(request)
    assert(result.success and request.targets.size() == 1, "Actual expansion does not rewrite selection history.")
    assert(result.get_events(BattleCombatEvent.TYPE.BEFORE_TARGETED).size() == 1)
    assert(result.get_events(BattleCombatEvent.TYPE.DAMAGE).size() == 4)
    for foe in f.foes:
        assert(foe.get_stat(CombatStats.STATS.Mana).Current == (95 if foe == f.foes[0] else 98))
        assert(foe.get_stat(CombatStats.STATS.Health).Current == 80)
        if foe != f.foes[0]:
            continue
        var targets_foe := func(event): return event.target == foe
        var selection: BattleCombatEvent = (
            result.get_events(BattleCombatEvent.TYPE.BEFORE_TARGETED).filter(targets_foe)[0]
        )
        var first_hit: BattleCombatEvent = result.get_events(BattleCombatEvent.TYPE.HIT).filter(targets_foe)[0]
        assert(result.events.find(selection) < result.events.find(first_hit))
        assert(foe.action_targeted.get_connections().is_empty())
    await _free_fixture(f)


## Checks allied healing applies without hostile TARGETED events or reactions.
func _test_friendly_healing() -> void:
    var f := _fixture(1)
    var friend: BattleUnit = f.foes[0]
    friend.team_id = f.actor.team_id
    friend.get_stat(CombatStats.STATS.Health).restore_current(90)
    _grant(
        friend,
        _resource(
            &"no_friendly_reaction",
            CombatEffects.TRIGGER.TARGETED,
            CombatActions.TARGET.SELF,
            -10,
            CombatStats.STATS.Mana
        )
    )
    var action := _action(f.actor, [_resource(&"heal", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.ALLY, 5)])
    action.target = CombatActions.TARGET.ALLY
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"friendly_heal", f.actor, action, [friend])
    )
    assert(result.success and result.get_events(BattleCombatEvent.TYPE.BEFORE_TARGETED).is_empty())
    assert(friend.get_stat(CombatStats.STATS.Health).Current == 95)
    assert(friend.get_stat(CombatStats.STATS.Mana).Current == 100)
    await _free_fixture(f)


## Checks two missed damage operations still dispatch one hostile selection reaction.
func _test_miss_selection() -> void:
    var f := _fixture(1)
    _override_stat(f.actor, CombatStats.STATS.Accuracy, 0)
    _grant(
        f.foes[0],
        _resource(
            &"selection_on_miss", CombatEffects.TRIGGER.TARGETED, CombatActions.TARGET.SELF, -3, CombatStats.STATS.Mana
        )
    )
    _grant(
        f.foes[0],
        _resource(
            &"no_damage_on_miss", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.SELF, -1, CombatStats.STATS.Mana
        )
    )
    var action := _two_hits(f.actor)
    action.always_hits = false
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"targeted_miss", f.actor, action, f.foes)
    )
    assert(result.success and result.get_events(BattleCombatEvent.TYPE.MISS).size() == 2)
    assert(result.get_events(BattleCombatEvent.TYPE.BEFORE_TARGETED).size() == 1)
    assert(f.foes[0].get_stat(CombatStats.STATS.Mana).Current == 97)
    await _free_fixture(f)


## Checks mutual TARGETED counters terminate and primitive damage in the same trigger bucket does
## not recurse.
func _test_targeted_counter_cycle() -> void:
    var f := _fixture(1)
    var first := _counter(&"selected_actor_counter", 3)
    first.trigger = CombatEffects.TRIGGER.TARGETED
    first.triggers[0].target = CombatActions.TARGET.FOE  # Incoming source, not last actual damage.
    first.triggers[0].trigger = CombatEffects.TRIGGER.TARGETED
    _grant(f.actor, first)
    var second := _counter(&"selected_foe_counter", 3)
    second.trigger = CombatEffects.TRIGGER.TARGETED
    second.triggers[0].target = CombatActions.TARGET.FOE
    second.triggers[0].trigger = CombatEffects.TRIGGER.TARGETED
    _grant(f.foes[0], second)
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"targeted_counters", f.actor, _two_hits(f.actor), f.foes)
    )
    assert(result.success and result.get_events(BattleCombatEvent.TYPE.BEFORE_TARGETED).size() == 1)
    assert(result.get_events(BattleCombatEvent.TYPE.DAMAGE).size() == 3)
    assert(f.actor.get_stat(CombatStats.STATS.Health).Current == 47)
    assert(f.foes[0].get_stat(CombatStats.STATS.Health).Current == 80)
    await _free_fixture(f)


## Checks cancellation during selection prevents damage and disconnects targeting/hit capture
## subscriptions.
func _test_cancel_on_selection() -> void:
    var f := _fixture(1)
    var running := {"active": true}
    f.foes[0].action_targeted.connect(func(_report): running.active = false, CONNECT_ONE_SHOT)
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"selection_cancel", f.actor, _two_hits(f.actor), f.foes), func(): return running.active
    )
    assert(not result.success and f.foes[0].get_stat(CombatStats.STATS.Health).Current == 100)
    assert(f.foes[0].action_targeted.get_connections().is_empty())
    assert(f.foes[0].damage_hit_resolved.get_connections().is_empty())
    await _free_fixture(f)
