extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/damage_reaction_smoke_suite.gd"
## Production round/defeat scopes use fresh damage contexts, not an old action.


class PendingRoundEffect:
    extends EffectBase

    func apply() -> void:
        _begin_apply()  # Deliberately unfinished, to exercise cancellation cleanup.


## Runs round-tick and defeat-trigger damage checks for attribution, independent accuracy, proc
## isolation and cancellation.
func run() -> void:
    await _test_defeated_dot_source()
    await _test_independent_tick_accuracy()
    await _test_no_stale_action_procs()
    await _test_counter_does_not_erase_existing_dot()
    await _test_defeat_damage()
    await _test_pending_tick_cancellation()


## Attaches a fixture round-based damage effect with explicit accuracy policy and duration to the
## recipient.
func _dot(
    source: BattleUnit, target: BattleUnit, id: StringName, amount: float, always_hits: bool = true, rounds: int = 2
) -> EffectBase:
    var definition := _resource(id, CombatEffects.TRIGGER.ROUND_OVER, CombatActions.TARGET.FOE, -amount)
    definition.always_hits = always_hits
    definition.kind = CombatEffects.KIND.REPEAT
    definition.lifetime = EffectTemplate.LIFETIME.ROUNDS
    definition.duration = rounds
    return target.add_effect(source, target, definition, {"source_id": id})


## Filters captured combat events by the requested event type.
func _events(events: Array[BattleCombatEvent], type: BattleCombatEvent.TYPE) -> Array[BattleCombatEvent]:
    return events.filter(func(event): return event.type == type)


## Verifies existing periodic damage retains a defeated source's attribution while excluding new
## after-hit procs from that source.
func _test_defeated_dot_source() -> void:
    var f := _fixture(2)
    var source: BattleUnit = f.foes[0]
    var tick := _dot(source, f.actor, &"posthumous_dot", 5)
    _grant(
        f.actor,
        _resource(&"incoming_dot", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.SELF, -1, CombatStats.STATS.Mana)
    )
    _grant(
        source,
        _resource(
            &"dead_source_proc",
            CombatEffects.TRIGGER.AFTER_HITTING,
            CombatActions.TARGET.SELF,
            -10,
            CombatStats.STATS.Mana
        )
    )
    source.get_stat(CombatStats.STATS.Health).restore_current(0)
    var lifecycle := BattleEncounterEffects.new()
    for round_number in [1, 2]:
        var events := await lifecycle.end_round(f.scene.coordinator.roster, func(): return true, &"dead_dot_round")
        assert(_events(events, BattleCombatEvent.TYPE.DAMAGE).size() == 1)
        assert(_events(events, BattleCombatEvent.TYPE.HIT).size() == 1)
        assert(_events(events, BattleCombatEvent.TYPE.DAMAGE)[0].actor == source)
        assert(f.actor.last_hit_by == source)
        assert(f.actor.get_stat(CombatStats.STATS.Health).Current == 50 - 5 * round_number)
        assert(f.actor.get_stat(CombatStats.STATS.Mana).Current == 50 - round_number)
        assert(source.get_stat(CombatStats.STATS.Mana).Current == 100, "Defeated source does not run new hit procs.")
        assert(not tick.get_meta(EffectBase.CHAIN_CONTEXT_META).has("damage_reactions"))
        assert(tick.resolution_continuation.is_null())
    assert(tick.removed and tick.duration == 0)
    await _free_fixture(f)


## Verifies distinct periodic damage operations roll independently within the same round.
func _test_independent_tick_accuracy() -> void:
    var f := _fixture(1)
    _prepare(f)
    _dot(f.actor, f.foes[0], &"first_tick", 10, false, 1)
    _dot(f.actor, f.foes[0], &"second_tick", 10, false, 1)
    _grant(
        f.foes[0],
        _resource(
            &"tick_reaction", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.SELF, -1, CombatStats.STATS.Mana
        )
    )
    var lifecycle := BattleEncounterEffects.new()
    var events := await lifecycle.end_round(f.scene.coordinator.roster, func(): return true)
    assert(_events(events, BattleCombatEvent.TYPE.HIT).size() == 1)
    assert(_events(events, BattleCombatEvent.TYPE.MISS).size() == 1)
    assert(_events(events, BattleCombatEvent.TYPE.DAMAGE).size() == 1)
    assert(f.foes[0].get_stat(CombatStats.STATS.Health).Current == 90)
    assert(f.foes[0].get_stat(CombatStats.STATS.Mana).Current == 99)
    await _free_fixture(f)


## Verifies later periodic damage does not replay the originating cast's authored hit procs.
func _test_no_stale_action_procs() -> void:
    var f := _fixture(1)
    var dot := _resource(&"granted_dot", CombatEffects.TRIGGER.ROUND_OVER, CombatActions.TARGET.FOE, -2)
    dot.always_hits = true
    dot.kind = CombatEffects.KIND.REPEAT
    dot.lifetime = EffectTemplate.LIFETIME.ROUNDS
    dot.duration = 2
    var action := _action(
        f.actor,
        [
            _resource(&"direct", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -5),
            dot,
            _resource(
                &"action_only_proc",
                CombatEffects.TRIGGER.AFTER_HITTING,
                CombatActions.TARGET.SELF,
                1,
                CombatStats.STATS.Mana
            ),
        ]
    )
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"grant_dot", f.actor, action, f.foes)
    )
    assert(result.success and f.actor.get_stat(CombatStats.STATS.Mana).Current == 51)
    var lifecycle := BattleEncounterEffects.new()
    await lifecycle.end_round(f.scene.coordinator.roster, func(): return true)
    assert(f.foes[0].get_stat(CombatStats.STATS.Health).Current == 93)
    assert(
        f.actor.get_stat(CombatStats.STATS.Mana).Current == 51, "Ticks do not replay the old cast's authored proc list."
    )
    await _free_fixture(f)


## Verifies killing a periodic effect's source during a counter does not erase the already attached
## damage-over-time effect.
func _test_counter_does_not_erase_existing_dot() -> void:
    var f := _fixture(1)
    _dot(f.actor, f.foes[0], &"surviving_dot", 10)
    _grant(f.foes[0], _counter(&"lethal_tick_counter", 100))
    var lifecycle := BattleEncounterEffects.new()
    var events := await lifecycle.end_round(f.scene.coordinator.roster, func(): return true)
    assert(not f.actor.is_active and f.foes[0].get_stat(CombatStats.STATS.Health).Current == 90)
    assert(_events(events, BattleCombatEvent.TYPE.DAMAGE).size() == 2)
    assert(f.foes[0].last_hit_by == f.actor, "An already-applied DOT survives source defeat during reactions.")
    await _free_fixture(f)


## Verifies damage from defeat-trigger effects is captured with the original source and receives
## scoped reactions.
func _test_defeat_damage() -> void:
    var f := _fixture(1)
    var death := _counter(&"death_counter", 5)
    death.trigger = CombatEffects.TRIGGER.DEFEAT
    _grant(f.actor, death)
    _grant(
        f.foes[0],
        _resource(
            &"death_incoming", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.SELF, -1, CombatStats.STATS.Mana
        )
    )
    f.actor.add_effect(
        f.foes[0], f.actor, _resource(&"lethal_attack", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -100)
    )
    var lifecycle := BattleEncounterEffects.new()
    var events := await lifecycle.process_defeats(f.scene.coordinator.roster, func(): return true)
    assert(_events(events, BattleCombatEvent.TYPE.DAMAGE).size() == 1)
    assert(_events(events, BattleCombatEvent.TYPE.DAMAGE)[0].actor == f.actor)
    assert(f.foes[0].get_stat(CombatStats.STATS.Health).Current == 95)
    assert(f.foes[0].get_stat(CombatStats.STATS.Mana).Current == 99)
    assert((await lifecycle.process_defeats(f.scene.coordinator.roster, func(): return true)).is_empty())
    await _free_fixture(f)


## Verifies cancellation during a round reaction stops pending damage and restores
## capture/continuation state.
func _test_pending_tick_cancellation() -> void:
    var f := _fixture(1)
    var pending := PendingRoundEffect.new()
    pending.name = &"PendingRoundEffect"
    var definition := EffectTemplate.new()
    definition.id = &"pending_round"
    definition.trigger = CombatEffects.TRIGGER.ROUND_OVER
    definition.lifetime = EffectTemplate.LIFETIME.ROUNDS
    definition.duration = 2
    pending.setup(f.actor, f.foes[0], definition)
    f.foes[0].effect_manager.on_round_over_holder.add_child(pending)
    var running := {"active": true, "finished": false}
    var lifecycle := BattleEncounterEffects.new()
    var run_round := func():
        await lifecycle.end_round(f.scene.coordinator.roster, func(): return running.active)
        running.finished = true
    run_round.call()
    await get_tree().process_frame
    assert(pending.applied_this_cycle and not running.finished)
    running.active = false
    for _frame in 10:
        if running.finished:
            break
        await get_tree().process_frame
    assert(running.finished and pending.duration == 2)
    assert(not pending.get_meta(EffectBase.CHAIN_CONTEXT_META, {}).has("damage_reactions"))
    assert(pending.resolution_continuation.is_null())
    assert(f.foes[0].resource_operation_resolved.get_connections().is_empty())
    await _free_fixture(f)
