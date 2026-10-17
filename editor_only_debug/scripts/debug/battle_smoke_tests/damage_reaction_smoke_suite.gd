extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/per_effect_hit_smoke_suite.gd"
## Per-operation reaction dispatch without replaying authored damage buckets.

const CHAIN_SCENE := preload("res://GrimDaysBattle/scenes/battle/effects/effect_trigger_chain.tscn")


## Runs reaction ordering, accuracy, counter recursion, defeat, mitigation and cancellation checks
## on disposable battle fixtures.
func run() -> void:
    await _test_freed_snapshot_entry()
    await _test_independent_reactions()
    await _test_misses_have_no_damage_reactions()
    await _test_counter_recursion()
    await _test_counter_defeats_actor()
    await _test_reaction_changes_mitigation()
    await _test_cancelled_reaction()
    await _test_lethal_windows()
    await _test_updated_scaling_and_zero_damage()


## Attaches the supplied fixture effect to its owning unit with a source ID derived from the
## definition.
func _grant(unit: BattleUnit, definition: EffectTemplate) -> EffectBase:
    definition.kind = CombatEffects.KIND.REPEAT
    definition.lifetime = EffectTemplate.LIFETIME.WHILE_SOURCE_ACTIVE
    return unit.add_effect(
        unit, unit, definition, {"source_id": StringName("passive:%s" % definition.id), "defer_application": true}
    )


## Authors a DAMAGED reaction chain containing a damage operation against the incoming attacker.
func _counter(id: StringName, damage: float) -> EffectTriggerAnotherEffect:
    var chain := EffectTriggerAnotherEffect.new()
    chain.id = id
    chain.trigger = CombatEffects.TRIGGER.DAMAGED
    chain.target = CombatActions.TARGET.SELF
    chain.template_scene = CHAIN_SCENE
    var hit := _resource(
        StringName("%s_hit" % id), CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.LAST_DAMAGED_BY, -damage
    )
    hit.always_hits = true
    chain.triggers = [hit]
    return chain


## Builds a fixture action with two independent damage operations for per-hit reaction checks.
func _two_hits(actor: BattleUnit) -> ActionTemplate:
    return _action(
        actor,
        [
            _resource(&"first", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -10),
            _resource(&"second", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -10),
        ]
    )


## Checks once-per-selection targeting, per-operation incoming reactions and independent
## authored/passive after-hit effects without replaying costs or damage.
func _test_independent_reactions() -> void:
    var f := _fixture(1)
    _grant(
        f.foes[0],
        _resource(&"incoming", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.SELF, -1, CombatStats.STATS.Mana)
    )
    _grant(
        f.foes[0],
        _resource(&"selected", CombatEffects.TRIGGER.TARGETED, CombatActions.TARGET.SELF, -3, CombatStats.STATS.Mana)
    )
    _grant(
        f.actor,
        _resource(&"on_hit", CombatEffects.TRIGGER.AFTER_HITTING, CombatActions.TARGET.SELF, 2, CombatStats.STATS.Mana)
    )
    var action := _two_hits(f.actor)
    action.ranks.all[0].effects.all.append(
        _resource(&"authored_after", CombatEffects.TRIGGER.AFTER_HITTING, CombatActions.TARGET.SELF, 4)
    )
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"reaction_counts", f.actor, action, f.foes)
    )
    assert(result.success and result.get_events(BattleCombatEvent.TYPE.DAMAGE).size() == 2)
    assert(f.foes[0].get_stat(CombatStats.STATS.Health).Current == 80, "No replay of authored DAMAGED operations.")
    assert(f.foes[0].get_stat(CombatStats.STATS.Mana).Current == 95, "One selection, two incoming operations.")
    assert(f.actor.get_stat(CombatStats.STATS.Mana).Current == 54, "Two separate after-hit passive calls.")
    assert(f.actor.get_stat(CombatStats.STATS.Health).Current == 58, "Authored after-hit operations run once per hit.")
    assert(f.actor.get_stat(CombatStats.STATS.Energy).Current == 97)
    await _free_fixture(f)


## Checks that only the successful operation in a seeded mixed pair dispatches damage reactions.
func _test_misses_have_no_damage_reactions() -> void:
    var f := _fixture(1)
    _prepare(f)
    _grant(
        f.foes[0],
        _resource(&"incoming", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.SELF, -1, CombatStats.STATS.Mana)
    )
    _grant(
        f.actor,
        _resource(&"on_hit", CombatEffects.TRIGGER.AFTER_HITTING, CombatActions.TARGET.SELF, 2, CombatStats.STATS.Mana)
    )
    var action := _two_hits(f.actor)
    action.always_hits = false
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"mixed_reactions", f.actor, action, f.foes)
    )
    assert(result.success and result.get_events(BattleCombatEvent.TYPE.MISS).size() == 1)
    assert(f.foes[0].get_stat(CombatStats.STATS.Mana).Current == 99)
    assert(f.actor.get_stat(CombatStats.STATS.Mana).Current == 52)
    await _free_fixture(f)


## Checks mutual counters terminate within each incoming operation, preserve attacker attribution
## and restore scoped effect context.
func _test_counter_recursion() -> void:
    var f := _fixture(1)
    var first := _grant(f.actor, _counter(&"actor_counter", 3))
    var second := _grant(f.foes[0], _counter(&"foe_counter", 3))
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"mutual_counters", f.actor, _two_hits(f.actor), f.foes)
    )
    assert(result.success and result.get_events(BattleCombatEvent.TYPE.DAMAGE).size() == 4)
    assert(f.actor.get_stat(CombatStats.STATS.Health).Current == 44)
    assert(f.foes[0].get_stat(CombatStats.STATS.Health).Current == 80)
    assert(f.actor.last_hit_by == f.foes[0] and f.foes[0].last_hit_by == f.actor)
    assert(not first.ticked and not second.ticked, "The next distinct incoming operation can react again.")
    assert(not first.get_meta(EffectBase.CHAIN_CONTEXT_META).has("damage_reactions"), "Scoped context is restored.")
    for event in result.get_events(BattleCombatEvent.TYPE.DAMAGE):
        if event.data.effect_id == &"foe_counter_hit":
            assert(event.actor == f.foes[0] and event.target == f.actor)
    await _free_fixture(f)


## Checks lethal incoming counters prevent pending and later outgoing damage while finishing the
## action once.
func _test_counter_defeats_actor() -> void:
    var f := _fixture(1)
    _grant(f.foes[0], _counter(&"lethal_counter", 100))
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"counter_defeat", f.actor, _two_hits(f.actor), f.foes)
    )
    assert(result.success and f.actor in result.defeated)
    assert(f.actor.get_stat(CombatStats.STATS.Health).Current == 0)
    assert(f.foes[0].get_stat(CombatStats.STATS.Health).Current == 90)
    assert(result.get_events(BattleCombatEvent.TYPE.DAMAGE).size() == 2, "Post-damage counter cancels later damage.")
    assert(result.get_events(BattleCombatEvent.TYPE.ACTION_FINISHED).size() == 1)
    await _free_fixture(f)


## Checks a reaction's resistance modifier affects the pending damage calculation.
func _test_reaction_changes_mitigation() -> void:
    var f := _fixture(1)
    # No test override on resistance: the source-owned reactive grant must be read
    # after incoming reactions, not cached before them.
    f.foes[0].get_stat(CombatStats.STATS.PhysicalResistance).set_base(0)
    var defense := EffectFlatChangeStatTemplate.new()
    defense.id = &"reactive_resistance"
    defense.trigger = CombatEffects.TRIGGER.BEFORE_DAMAGE
    defense.target = CombatActions.TARGET.SELF
    defense.stat = CombatStats.STATS.PhysicalResistance
    defense.flat_amount = 50
    defense.template_scene = STAT_EFFECT_SCENE
    _grant(f.foes[0], defense)
    var hit := _resource(&"physical", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -20)
    hit.damage_type = CombatDamage.TYPE.Physical
    var resistance: float = f.foes[0].get_stat(CombatStats.STATS.PhysicalResistance).Current
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"reactive_resist", f.actor, _action(f.actor, [hit]), f.foes)
    )
    assert(result.success and f.foes[0].get_stat(CombatStats.STATS.PhysicalResistance).Current >= resistance + 50)
    assert(
        (
            result.get_events(BattleCombatEvent.TYPE.DAMAGE)[0].amount
            <= ceilf(10 * CombatDamage.PHYSICAL_DAMAGE_MAX_MODIFIER)
        )
    )
    await _free_fixture(f)


## Checks cancellation during a reaction prevents damage and removes scoped context and capture
## connections.
func _test_cancelled_reaction() -> void:
    var f := _fixture(1)
    var reaction := _grant(
        f.foes[0],
        _resource(
            &"cancel_reaction",
            CombatEffects.TRIGGER.BEFORE_DAMAGE,
            CombatActions.TARGET.SELF,
            -1,
            CombatStats.STATS.Mana
        )
    )
    var running := {"active": true}
    f.foes[0].resource_operation_resolved.connect(func(_report): running.active = false, CONNECT_ONE_SHOT)
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"reaction_cancel", f.actor, _two_hits(f.actor), f.foes), func(): return running.active
    )
    assert(not result.success and f.foes[0].get_stat(CombatStats.STATS.Health).Current == 100)
    assert(not reaction.get_meta(EffectBase.CHAIN_CONTEXT_META).has("damage_reactions"))
    assert(f.foes[0].resource_operation_resolved.get_connections().is_empty())
    await _free_fixture(f)


## Lethal damage still opens DAMAGED; either rescue window prevents later KILL processing.
func _test_lethal_windows() -> void:
    for rescue in [CombatEffects.TRIGGER.DAMAGED, CombatEffects.TRIGGER.DEFEAT, -1]:
        var f := _fixture(1)
        var defender: BattleUnit = f.foes[0]
        defender.get_stat(CombatStats.STATS.Health).restore_current(10)
        var trace: Array[StringName] = []
        defender.action_targeted.connect(func(_report): trace.append(&"targeted"))
        defender.damage_hit_resolved.connect(func(_report): trace.append(&"hit"))
        for unit: BattleUnit in [f.actor, defender]:
            unit.resource_operation_resolved.connect(func(report): trace.append(report.effect_id))
        _grant(
            f.actor,
            _resource(
                &"attacking", CombatEffects.TRIGGER.ATTACKING, CombatActions.TARGET.SELF, 0, CombatStats.STATS.Mana
            )
        )
        _grant(
            defender,
            _resource(
                &"before", CombatEffects.TRIGGER.BEFORE_DAMAGE, CombatActions.TARGET.SELF, 0, CombatStats.STATS.Mana
            )
        )
        _grant(
            f.actor,
            _resource(
                &"after", CombatEffects.TRIGGER.AFTER_HITTING, CombatActions.TARGET.SELF, 0, CombatStats.STATS.Mana
            )
        )
        for trigger in [CombatEffects.TRIGGER.DAMAGED, CombatEffects.TRIGGER.DEFEAT]:
            var name_id: StringName = &"damaged" if trigger == CombatEffects.TRIGGER.DAMAGED else &"defeat"
            var stat := CombatStats.STATS.Health if trigger == rescue else CombatStats.STATS.Mana
            _grant(
                defender, _resource(name_id, trigger, CombatActions.TARGET.SELF, 5 if trigger == rescue else 0, stat)
            )
        _grant(
            f.actor,
            _resource(&"kill", CombatEffects.TRIGGER.KILL, CombatActions.TARGET.SELF, 0, CombatStats.STATS.Mana)
        )
        var action := _action(
            f.actor, [_resource(&"damage", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -10)]
        )
        var result: BattleActionResolution = await f.resolver.resolve(
            BattleActionRequest.new(&"lethal_windows", f.actor, action, f.foes)
        )
        assert(result.success)
        var expected: Array[StringName] = [
            &"targeted", &"attacking", &"hit", &"before", &"after", &"damage", &"damaged"
        ]
        if rescue != CombatEffects.TRIGGER.DAMAGED:
            expected.append(&"defeat")
        if rescue == -1:
            expected.append(&"kill")
        assert(trace == expected, "Actual reaction trace: %s" % [trace])
        assert(defender.is_active == (rescue != -1))
        assert(result.defeated.is_empty() == defender.is_active)
        var lifecycle := BattleEncounterEffects.new()
        await lifecycle.process_defeats(f.scene.coordinator.roster, func(): return true)
        assert(trace == expected, "Production handoff cannot replay completed defeat/kill responses.")
        await _free_fixture(f)


## AFTER_HITTING changes feed the pending magnitude; successful zero damage still opens DAMAGED.
func _test_updated_scaling_and_zero_damage() -> void:
    for zero_damage in [false, true]:
        var f := _fixture(1)
        var hit := (
            BASIC_ATTACK.get_rank_template(1).effects.all[0].duplicate(true) as EffectScalingCombatStatChangeTemplate
        )
        hit.scales_with = CombatStats.STATS.Mana
        hit.scales_from_sender = true
        hit.scales_with_damage = false
        hit.scales_by = -1
        hit.damage_type = CombatDamage.TYPE.True
        hit.can_critical = false
        if zero_damage:
            f.actor.get_stat(CombatStats.STATS.Mana).restore_current(0)
        else:
            _grant(
                f.actor,
                _resource(
                    &"increase_outgoing",
                    CombatEffects.TRIGGER.AFTER_HITTING,
                    CombatActions.TARGET.SELF,
                    10,
                    CombatStats.STATS.Mana
                )
            )
        _grant(
            f.foes[0],
            _resource(
                &"damage_window", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.SELF, -1, CombatStats.STATS.Mana
            )
        )
        var result: BattleActionResolution = await f.resolver.resolve(
            BattleActionRequest.new(&"updated_magnitude", f.actor, _action(f.actor, [hit]), f.foes)
        )
        assert(result.success and result.get_events(BattleCombatEvent.TYPE.DAMAGE).size() == 1)
        assert(result.get_events(BattleCombatEvent.TYPE.DAMAGE)[0].amount == (0 if zero_damage else 60))
        assert(f.foes[0].get_stat(CombatStats.STATS.Mana).Current == 99)
        await _free_fixture(f)


## Frees a later snapshot entry during the same frame wait used by animation reactions.
class RemovingReaction:
    extends EffectBase
    var victim: EffectBase

    func apply() -> void:
        if not _begin_apply():
            return
        victim.remove()
        await get_tree().process_frame
        await get_tree().process_frame
        _finish_apply()


## Both loop-end and continue must skip a freed entry and still run surviving reactions.
func _test_freed_snapshot_entry() -> void:
    for skip_before_victim in [false, true]:
        var f := _fixture(1)
        var defender: BattleUnit = f.foes[0]
        var holder: EffectDirectors = defender.effect_manager.triggers_to_holders[CombatEffects.TRIGGER.DAMAGED]
        var definition := _resource(
            &"removing_reaction", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.SELF, 0, CombatStats.STATS.Mana
        )
        definition.kind = CombatEffects.KIND.REPEAT
        definition.lifetime = EffectTemplate.LIFETIME.WHILE_SOURCE_ACTIVE
        var removing := RemovingReaction.new()
        removing.name = "RemovingReaction"
        removing.setup(defender, defender, definition)
        holder.add_child(removing)
        if skip_before_victim:
            var skipped := _grant(
                defender,
                _resource(
                    &"skipped_snapshot_entry",
                    CombatEffects.TRIGGER.DAMAGED,
                    CombatActions.TARGET.SELF,
                    -20,
                    CombatStats.STATS.Mana
                )
            )
            skipped.set_chain_context({"action_operation": true})
        var victim := _grant(
            defender,
            _resource(
                &"freed_snapshot_entry",
                CombatEffects.TRIGGER.DAMAGED,
                CombatActions.TARGET.SELF,
                -30,
                CombatStats.STATS.Mana
            )
        )
        removing.victim = victim
        _grant(
            defender,
            _resource(
                &"surviving_snapshot_entry",
                CombatEffects.TRIGGER.DAMAGED,
                CombatActions.TARGET.SELF,
                -1,
                CombatStats.STATS.Mana
            )
        )
        var before := defender.get_stat(CombatStats.STATS.Mana).Current
        var reactions := BattleDamageReactions.new()
        await reactions._dispatch(defender, CombatEffects.TRIGGER.DAMAGED, f.actor, func(): return true)
        assert(not is_instance_valid(victim), "The snapshot must contain an actually freed node.")
        assert(
            defender.get_stat(CombatStats.STATS.Mana).Current == before - 1,
            "Freed/skipped entries must not run; surviving reactions must still resolve."
        )
        assert(reactions._active.is_empty(), "Dispatch must release its active-reaction bookkeeping.")
        await _free_fixture(f)
