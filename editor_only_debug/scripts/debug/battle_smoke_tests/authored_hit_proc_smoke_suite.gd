extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/damage_reaction_smoke_suite.gd"
## Authored action procs inherit each hit's actual recipient, not cast-wide scope.


func run() -> void:
    await _test_proc_chain_cannot_repeat_itself()
    await _test_area_recipient_procs()
    await _test_mixed_and_non_damage()
    await _test_delay_per_hit()


## Appends an AFTER_HITTING chain to the fixture action so supplied operations run as authored
## per-hit procs.
func _append_proc(action: ActionTemplate, effects: Array[EffectTemplate]) -> void:
    var chain := EffectTriggerAnotherEffect.new()
    chain.id = &"authored_hit_proc"
    chain.target = CombatActions.TARGET.SELF
    chain.trigger = CombatEffects.TRIGGER.AFTER_HITTING
    chain.template_scene = CHAIN_SCENE
    chain.triggers = effects
    action.ranks.all[0].effects.all.append(chain)


## Verifies one proc chain per base hit, no recursive proc scheduling and one action cost/finish.
func _test_proc_chain_cannot_repeat_itself() -> void:
    var f := _fixture(1)
    var action := _two_hits(f.actor)
    var extra := _resource(&"proc_damage", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.LAST_HIT, -1)
    extra.always_hits = true
    _append_proc(
        action,
        [
            extra,
            _resource(
                &"proc_mana", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.LAST_HIT, -1, CombatStats.STATS.Mana
            )
        ]
    )
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"bounded_proc", f.actor, action, f.foes)
    )
    assert(result.success and result.get_events(BattleCombatEvent.TYPE.DAMAGE).size() == 4)
    assert(f.foes[0].get_stat(CombatStats.STATS.Health).Current == 78)
    assert(f.foes[0].get_stat(CombatStats.STATS.Mana).Current == 98)
    assert(f.actor.get_stat(CombatStats.STATS.Energy).Current == 97)
    assert(result.get_events(BattleCombatEvent.TYPE.ACTION_FINISHED).size() == 1)
    var hits := result.get_events(BattleCombatEvent.TYPE.DAMAGE)
    assert(hits[0].data.effect_id == &"proc_damage" and hits[1].data.effect_id == &"first")
    assert(hits[2].data.effect_id == &"proc_damage" and hits[3].data.effect_id == &"second")
    await _free_fixture(f)


## Verifies that each actual area recipient receives a proc for each successful damage operation.
func _test_area_recipient_procs() -> void:
    var f := _fixture(2)
    var action := _action(
        f.actor,
        [
            _resource(&"area_a", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOES, -10),
            _resource(&"area_b", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOES, -10),
            _resource(
                &"recipient_proc",
                CombatEffects.TRIGGER.AFTER_HITTING,
                CombatActions.TARGET.FOE,
                -1,
                CombatStats.STATS.Mana
            ),
        ]
    )
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"area_procs", f.actor, action, f.foes)
    )
    assert(result.success and result.get_events(BattleCombatEvent.TYPE.DAMAGE).size() == 4)
    for foe in f.foes:
        assert(foe.get_stat(CombatStats.STATS.Health).Current == 80)
        assert(foe.get_stat(CombatStats.STATS.Mana).Current == 98, "Two procs per actual recipient.")
    await _free_fixture(f)


## Verifies misses and healing do not schedule authored hit procs.
func _test_mixed_and_non_damage() -> void:
    var f := _fixture(1)
    _prepare(f)
    var action := _two_hits(f.actor)
    action.always_hits = false
    action.ranks.all[0].effects.all.append(
        _resource(&"on_hit", CombatEffects.TRIGGER.AFTER_HITTING, CombatActions.TARGET.FOE, -1, CombatStats.STATS.Mana)
    )
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"mixed_procs", f.actor, action, f.foes)
    )
    assert(result.success and result.get_events(BattleCombatEvent.TYPE.MISS).size() == 1)
    assert(f.foes[0].get_stat(CombatStats.STATS.Mana).Current == 99)
    # A healing-only action must not manufacture a successful attack proc.
    action.ranks.all[0].effects.all[0].amount = 1
    action.ranks.all[0].effects.all[1].amount = 1
    result = await f.resolver.resolve(BattleActionRequest.new(&"healing_no_proc", f.actor, action, f.foes))
    assert(result.success and result.get_events(BattleCombatEvent.TYPE.HIT).is_empty())
    assert(f.foes[0].get_stat(CombatStats.STATS.Mana).Current == 99)
    await _free_fixture(f)


## Verifies two successful hits each delay the target one pending position without starting or
## consuming another turn.
func _test_delay_per_hit() -> void:
    var f := _fixture(3)
    _override_stat(f.actor, CombatStats.STATS.Swiftness, 1000)
    var coordinator: BattleCoordinator = f.scene.coordinator
    assert(coordinator.begin_round(coordinator.session_id))
    assert(coordinator.record_turn_started(coordinator.session_id))
    assert(coordinator.turn_order.get_active_unit() == f.actor)
    var target: BattleUnit = coordinator.turn_order.get_units()[1]
    var before := coordinator.turn_order.get_units()
    var action := _two_hits(f.actor)
    var delay := EffectDelayTurnTemplate.new()
    delay.id = &"heavy_blows_test"
    delay.target = CombatActions.TARGET.LAST_HIT
    delay.trigger = CombatEffects.TRIGGER.AFTER_HITTING
    delay.template_scene = load("res://GrimDaysBattle/scenes/battle/effects/effect_delay_turn.tscn")
    action.ranks.all[0].effects.all.append(delay)
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"heavy_blows", f.actor, action, [target])
    )
    assert(result.success and result.get_events(BattleCombatEvent.TYPE.TURN_DELAY).size() == 2)
    assert(coordinator.turn_order.get_units() == [before[0], before[2], before[3], before[1]])
    assert(coordinator.current_result.turns == 1, "A delay proc never consumes or starts a turn.")
    await _free_fixture(f)
