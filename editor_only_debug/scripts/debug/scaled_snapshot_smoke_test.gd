# Focused timed-scaling and mitigation checks, isolated from unfinished authored skill trees.
extends "res://editor_only_debug/scripts/debug/ranked_effect_modifiers_smoke_test.gd"


func _ready() -> void:
    await _test_snapshots()
    await _test_mitigation_bypass()
    await _test_critical_and_authored_bleed()
    await _test_ranked_combat_modifiers()
    print("SCALED_SNAPSHOT_SMOKE_TEST: PASS") # lint:ignore debug-print -- Required test/CLI output.


func _definition(id: StringName, amount: float = -0.1) -> EffectScalingCombatStatChangeTemplate:
    var effect := _strike(id)
    effect.kind = CombatEffects.KIND.DEBUFF if amount < 0 else CombatEffects.KIND.BUFF
    effect.lifetime = EffectTemplate.LIFETIME.ROUNDS
    effect.duration = 3
    effect.trigger = CombatEffects.TRIGGER.ROUND_OVER
    effect.scales_by = amount
    effect.scales_with_damage = true
    effect.can_critical = false
    effect.stacking = EffectTemplate.STACKING.MULTIPLE
    effect.description = "Take x damage each round."
    return effect


func _test_snapshots() -> void:
    var f := _fixture(1)
    var actor: BattleUnit = f.actor
    var target: BattleUnit = f.foes[0]
    _override_stat(actor, CombatStats.STATS.PhysicalDamage, 100)
    _override_stat(actor, CombatStats.STATS.DamageModifier, 1)
    var definition := _definition(&"snapshot_dot")
    var first := target.add_effect(actor, target, definition) as EffectScaledStatChange
    assert(first.snapshot_ready and first.snapshot_change == -10)
    assert(first.get_description() == "Take 10 damage each round.")
    assert(definition.get_description() == "Take x damage each round.")
    _override_stat(actor, CombatStats.STATS.PhysicalDamage, 200)
    _override_stat(actor, CombatStats.STATS.DamageModifier, 2)
    var second := target.add_effect(actor, target, definition) as EffectScaledStatChange
    assert(second.snapshot_change == -40 and first.snapshot_change == -10)
    definition.description = "Take x% damage."
    assert(second.get_description() == "Take 10% damage.")
    definition.description = "Take x damage each round."
    first.apply()
    assert(target.get_stat(CombatStats.STATS.Health).Current == 90)
    first.on_round_end()
    first.apply()
    assert(target.get_stat(CombatStats.STATS.Health).Current == 80)
    second.apply()
    assert(target.get_stat(CombatStats.STATS.Health).Current == 40)
    var snapshot := BattleRetryCheckpoint.new()
    snapshot.capture([target])
    first.remove()
    second.remove()
    assert(snapshot.restore())
    var restored: Array[Node] = (
        target.effect_manager.triggers_to_holders[CombatEffects.TRIGGER.ROUND_OVER].get_children()
    )
    assert(restored.size() == 2)
    assert(restored[0].snapshot_change == -10 and restored[1].snapshot_change == -40)
    target.effect_manager.remove_battle_scoped_effects()
    await get_tree().process_frame
    # Refresh/combine preserve the initial value; only new instances take new snapshots.
    definition.stacking = EffectTemplate.STACKING.COMBINE
    first = target.add_effect(actor, target, definition)
    assert(first.snapshot_change == -40)
    _override_stat(actor, CombatStats.STATS.PhysicalDamage, 300)
    assert(target.add_effect(actor, target, definition) == first)
    assert(first.snapshot_change == -40 and first.duration == 6)
    target.effect_manager.remove_battle_scoped_effects()
    await get_tree().process_frame
    var healing := _definition(&"snapshot_healing", 0.1)
    var hot := target.add_effect(actor, target, healing) as EffectScaledStatChange
    assert(hot.snapshot_change == 60)
    _override_stat(actor, CombatStats.STATS.PhysicalDamage, 10)
    target.get_stat(CombatStats.STATS.Health).restore_current(0)
    hot.apply()
    assert(target.get_stat(CombatStats.STATS.Health).Current == 60)
    # REPEAT kind retains live scaling, even with a round duration.
    var live := _definition(&"live_scaling", 0.1)
    live.kind = CombatEffects.KIND.REPEAT
    var repeat := target.add_effect(actor, target, live) as EffectScaledStatChange
    assert(not repeat.snapshot_ready)
    _override_stat(actor, CombatStats.STATS.PhysicalDamage, 20)
    repeat.apply()
    assert(target.get_stat(CombatStats.STATS.Health).Current == 64)
    await _free_fixture(f)


func _test_mitigation_bypass() -> void:
    var f := _fixture(1)
    var actor: BattleUnit = f.actor
    var target: BattleUnit = f.foes[0]
    _override_stat(actor, CombatStats.STATS.PhysicalDamage, 100)
    _override_stat(actor, CombatStats.STATS.DamageModifier, 1)
    _override_stat(target, CombatStats.STATS.PhysicalResistance, 50)
    _override_stat(target, CombatStats.STATS.MagicResistance, 50)
    for damage_type in [CombatDamage.TYPE.Physical, CombatDamage.TYPE.Magic]:
        var blocked := _definition(&"mitigated_snapshot")
        blocked.damage_type = damage_type
        actor.randomizer.set_seed(73)
        var first := target.add_effect(actor, target, blocked) as EffectScaledStatChange
        var bypass := blocked.duplicate() as EffectScalingCombatStatChangeTemplate
        bypass.id = &"bypass_snapshot"
        bypass.bypass_mitigation = true
        actor.randomizer.set_seed(73)
        var second := target.add_effect(actor, target, bypass) as EffectScaledStatChange
        assert(is_equal_approx(second.snapshot_change, first.snapshot_change * 2))
        assert(first.snapshot_mitigation == 50 and second.snapshot_mitigation == 0)
        # Neither variance, source stats nor resistance changes reroll an existing snapshot.
        var frozen := first.snapshot_change
        _override_stat(target, CombatStats.STATS.PhysicalResistance, 100)
        _override_stat(target, CombatStats.STATS.MagicResistance, 100)
        first.apply()
        assert(is_equal_approx(first.get_resolution_report().raw_change, -10))
        first.on_round_end()
        actor.randomizer.set_seed(99)
        first.apply()
        assert(first.snapshot_change == frozen and first.mitigation_percent == 50)
        target.effect_manager.remove_battle_scoped_effects()
        await get_tree().process_frame
        _override_stat(target, CombatStats.STATS.PhysicalResistance, 50)
        _override_stat(target, CombatStats.STATS.MagicResistance, 50)
    # Non-snapshotted flat and scaled damage also honor bypass without losing physical identity.
    _override_stat(target, CombatStats.STATS.PhysicalResistance, 100)
    var flat := _resource(&"flat_bypass", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -10)
    flat.damage_type = CombatDamage.TYPE.Physical
    flat.bypass_mitigation = true
    flat.always_hits = true
    target.get_stat(CombatStats.STATS.Health).restore_current(100)
    var effect := target.add_effect(actor, target, flat, {"defer_application": true})
    effect.apply()
    assert(target.get_stat(CombatStats.STATS.Health).Current < 100)
    effect.remove()
    var scaled := _strike(&"scaled_bypass")
    scaled.damage_type = CombatDamage.TYPE.Physical
    scaled.bypass_mitigation = true
    scaled.can_critical = false
    target.get_stat(CombatStats.STATS.Health).restore_current(100)
    effect = target.add_effect(actor, target, scaled, {"defer_application": true})
    effect.apply()
    assert(target.get_stat(CombatStats.STATS.Health).Current < 100)
    effect.remove()
    await _free_fixture(f)


func _test_critical_and_authored_bleed() -> void:
    var f := _fixture(1)
    var actor: BattleUnit = f.actor
    var target: BattleUnit = f.foes[0]
    _override_stat(actor, CombatStats.STATS.PhysicalDamage, 100)
    _override_stat(actor, CombatStats.STATS.DamageModifier, 1)
    _override_stat(actor, CombatStats.STATS.CriticalStrike, 100)
    var definition := _definition(&"critical_snapshot")
    definition.can_critical = true
    definition.critical_damage_multiplier = 3
    var effect := target.add_effect(actor, target, definition) as EffectScaledStatChange
    assert(effect.snapshot_critical and effect.snapshot_change == -30)
    _override_stat(actor, CombatStats.STATS.CriticalStrike, 0)
    effect.apply()
    assert(effect.critical_hit and target.get_stat(CombatStats.STATS.Health).Current == 70)
    effect.remove()
    # Runtime load keeps this authored content check separate from the reusable fixture class.
    var slash := ( # lint:ignore load-in-var -- Load fixtures during test execution.
        load("res://GrimDaysBattle/resources/actions/celine/slash_single_rank/slash_single_rank.tres")
        as ActionTemplate
    )
    var bleed: EffectTemplate = slash.get_rank_template(1).effects.all[0].effects_on_hit[0].triggers[0]
    var stack := target.add_effect(actor, target, bleed) as EffectScaledStatChange
    assert(stack.snapshot_ready and stack.snapshot_raw_change == -2.5)
    var initial := stack.snapshot_change
    assert(stack.get_description() == bleed.get_description(absf(initial)))
    assert(stack.get_description() != "Take 0.025 damage at the end of every round.")
    _override_stat(actor, CombatStats.STATS.PhysicalDamage, 1000)
    assert(stack.snapshot_change == initial)
    await _free_fixture(f)
