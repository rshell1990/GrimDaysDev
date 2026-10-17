extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/action_trigger_routing_smoke_suite.gd"
## Immediate per-operation hit/critical behavior. Reaction dispatch is tested in
## the next integration batch, not implied by these accuracy-focused checks.


func run() -> void:
    await _test_mixed_rolls_and_chain()
    await _test_always_hit_and_crit()
    await _test_multiple_recipients()
    await _test_hit_cancellation()
    await _test_actor_stops_between_operations()
    await _test_zero_damage_and_victim_scaling()


## Installs a deterministic fixture override on the requested unit stat.
func _override_stat(unit: BattleUnit, stat_id: CombatStats.STATS, value: float) -> void:
    unit.get_stat(stat_id).add_modifier(
        UnitStatModifier.create(
            StringName("per_hit:%s" % stat_id), &"test:per_hit", stat_id, UnitStatModifier.OPERATION.OVERRIDE, value
        )
    )


## Sets controlled accuracy/evasion/critical values and seeds the actor for one hit and one miss.
func _prepare(f: Dictionary) -> void:
    _override_stat(f.actor, CombatStats.STATS.Accuracy, 50)
    _override_stat(f.actor, CombatStats.STATS.CriticalStrike, 0)
    _override_stat(f.actor, CombatStats.STATS.Luck, 0)
    for foe in f.foes:
        _override_stat(foe, CombatStats.STATS.Evasion, 0)
        _override_stat(foe, CombatStats.STATS.LuckyEvasion, 0)
        _override_stat(foe, CombatStats.STATS.PhysicalResistance, 0)
    f.actor.randomizer.set_seed(_mixed_seed())


## Find a portable seeded pair on opposite sides of 50%, avoiding dependence on
## a hard-coded sequence from one Godot build. Unit RNG then repeats that pair.
func _mixed_seed() -> int:
    var rng := RandomNumberGenerator.new()
    for seed_value in range(1, 1000):
        rng.seed = seed_value
        var first: bool = rng.randf_range(0, 100) < 50
        var second: bool = rng.randf_range(0, 100) < 50
        if first != second:
            return seed_value
    assert(false, "Expected a mixed seeded pair.")
    return 1


## Verifies independent damage rolls inside a chain, one hostile selection and no damage from the
## missed operation.
func _test_mixed_rolls_and_chain() -> void:
    var f := _fixture(1)
    _prepare(f)
    var chain := EffectTriggerAnotherEffect.new()
    chain.id = &"independent_chain"
    chain.trigger = CombatEffects.TRIGGER.DAMAGED
    chain.target = CombatActions.TARGET.FOE
    chain.kind = CombatEffects.KIND.ONCE
    chain.template_scene = load("res://GrimDaysBattle/scenes/battle/effects/effect_trigger_chain.tscn")
    chain.triggers = [
        _resource(&"first", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -10),
        _resource(&"second", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -10),
    ]
    var action := _action(f.actor, [chain])
    action.always_hits = false
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"mixed", f.actor, action, f.foes)
    )
    assert(result.success and result.get_events(BattleCombatEvent.TYPE.HIT).size() == 1)
    assert(result.get_events(BattleCombatEvent.TYPE.MISS).size() == 1)
    assert(result.get_events(BattleCombatEvent.TYPE.DAMAGE).size() == 1)
    assert(result.get_events(BattleCombatEvent.TYPE.BEFORE_TARGETED).size() == 1)
    assert(f.foes[0].get_stat(CombatStats.STATS.Health).Current == 90)
    assert(f.actor.get_stat(CombatStats.STATS.Energy).Current == 97)
    assert(result.get_events(BattleCombatEvent.TYPE.ACTION_FINISHED).size() == 1)
    await _free_fixture(f)


## Verifies forced accuracy and critical behavior at the effect/action compatibility boundaries.
func _test_always_hit_and_crit() -> void:
    var f := _fixture(1)
    _prepare(f)
    _override_stat(f.actor, CombatStats.STATS.Accuracy, 0)
    _override_stat(f.actor, CombatStats.STATS.CriticalStrike, 50)
    _override_stat(f.actor, CombatStats.STATS.PhysicalDamage, 10)
    _override_stat(f.foes[0], CombatStats.STATS.Evasion, 100)
    var first := (
        BASIC_ATTACK.get_rank_template(1).effects.all[0].duplicate(true) as EffectScalingCombatStatChangeTemplate
    )
    first.always_hits = true
    first.id = &"first_critical_roll"
    var second := first.duplicate() as EffectScalingCombatStatChangeTemplate
    second.id = &"second_critical_roll"
    var miss := _resource(&"must_miss", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -30)
    var action := _action(f.actor, [miss, first, second])
    action.always_hits = false
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"independent_crit", f.actor, action, f.foes)
    )
    assert(result.success and result.get_events(BattleCombatEvent.TYPE.MISS).size() == 1)
    assert(result.get_events(BattleCombatEvent.TYPE.HIT).size() == 2)
    assert(result.get_events(BattleCombatEvent.TYPE.CRITICAL).size() == 1)
    assert(result.get_events(BattleCombatEvent.TYPE.DAMAGE).size() == 2)
    for event in result.get_events(BattleCombatEvent.TYPE.HIT):
        assert(event.data.effect_id in [first.id, second.id])
    assert(result.get_events(BattleCombatEvent.TYPE.COST_PAID).size() == 1)
    await _free_fixture(f)


## Verifies separate accuracy checks for each actual recipient of an area operation.
func _test_multiple_recipients() -> void:
    var f := _fixture(2)
    _prepare(f)
    var first := _resource(&"area_first", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOES, -10)
    var second := _resource(&"area_second", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOES, -10)
    var action := _action(f.actor, [first, second])
    action.always_hits = false
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"recipient_rolls", f.actor, action, f.foes)
    )
    var outcomes := result.get_events(BattleCombatEvent.TYPE.HIT) + result.get_events(BattleCombatEvent.TYPE.MISS)
    assert(result.success and outcomes.size() == 4)
    for foe in f.foes:
        assert(outcomes.filter(func(event): return event.target == foe).size() == 2)
    assert(result.get_events(BattleCombatEvent.TYPE.BEFORE_TARGETED).size() == 2)
    await _free_fixture(f)


## Verifies cancellation during hit resolution prevents the pending resource change.
func _test_hit_cancellation() -> void:
    var f := _fixture(1)
    var running := {"active": true}
    var action := _action(
        f.actor, [_resource(&"cancelled_damage", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -10)]
    )
    f.foes[0].damage_hit_resolved.connect(func(_report): running.active = false, CONNECT_ONE_SHOT)
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"hit_cancel", f.actor, action, f.foes), func(): return running.active
    )
    assert(not result.success and f.foes[0].get_stat(CombatStats.STATS.Health).Current == 100)
    assert(f.foes[0].damage_hit_resolved.get_connections().is_empty())
    await _free_fixture(f)


## Verifies later operations stop after the actor becomes inactive during the action.
func _test_actor_stops_between_operations() -> void:
    var f := _fixture(1)
    var action := _action(
        f.actor,
        [
            _resource(&"first_before_defeat", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -10),
            _resource(&"second_after_defeat", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -10),
        ]
    )
    f.foes[0].resource_operation_resolved.connect(
        func(_report): f.actor.get_stat(CombatStats.STATS.Health).restore_current(0), CONNECT_ONE_SHOT
    )
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"actor_interrupted", f.actor, action, f.foes)
    )
    assert(result.success and result.get_events(BattleCombatEvent.TYPE.DAMAGE).size() == 1)
    assert(f.foes[0].get_stat(CombatStats.STATS.Health).Current == 90)
    assert(f.actor in result.defeated)
    await _free_fixture(f)


## Verifies zero damage and recipient-based scaling use the appropriate hit and resource-change
## behavior.
func _test_zero_damage_and_victim_scaling() -> void:
    var f := _fixture(1)
    _prepare(f)
    _override_stat(f.actor, CombatStats.STATS.PhysicalDamage, 0)
    _override_stat(f.actor, CombatStats.STATS.CriticalStrike, 100)
    _override_stat(f.foes[0], CombatStats.STATS.PhysicalDamage, 10)
    _override_stat(f.foes[0], CombatStats.STATS.CriticalStrike, 0)
    var zero := (
        BASIC_ATTACK.get_rank_template(1).effects.all[0].duplicate(true) as EffectScalingCombatStatChangeTemplate
    )
    zero.id = &"zero_damage"
    zero.can_critical = false
    var victim_scaled := zero.duplicate() as EffectScalingCombatStatChangeTemplate
    victim_scaled.id = &"victim_scaled"
    victim_scaled.can_critical = true
    victim_scaled.scales_from_sender = false
    var action := _action(f.actor, [zero, victim_scaled])
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"zero_victim", f.actor, action, f.foes)
    )
    assert(result.success and result.get_events(BattleCombatEvent.TYPE.HIT).size() == 2)
    assert(result.get_events(BattleCombatEvent.TYPE.DAMAGE).size() == 2)
    assert(result.get_events(BattleCombatEvent.TYPE.DAMAGE)[0].amount == 0)
    assert(result.get_events(BattleCombatEvent.TYPE.HEALING).is_empty())
    assert(result.get_events(BattleCombatEvent.TYPE.CRITICAL).size() == 1)
    assert(result.get_events(BattleCombatEvent.TYPE.CRITICAL)[0].actor == f.actor)
    assert(f.foes[0].last_hit_by == f.actor)
    await _free_fixture(f)
