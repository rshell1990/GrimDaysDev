extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"


## Runs the effect lifecycle smoke checks. Creates or uses test objects and stops on failed
## assertions.
func run() -> void:
    var unit := create_unit(CELINE_TEMPLATE)
    var strength := create_flat_stat(unit, CombatStats.STATS.Strength, 10.0)
    create_flat_stat(unit, CombatStats.STATS.Level, 1.0)
    create_flat_stat(unit, CombatStats.STATS.PhysicalDamage, 40.0)
    (
        strength
        . add_modifier(
            (
                UnitStatModifier
                . create(
                    &"strength_training_percent",
                    &"skill:strength_training",
                    CombatStats.STATS.Strength,
                    UnitStatModifier.OPERATION.PERCENT_ADD,
                    0.10,
                )
            )
        )
    )
    (
        strength
        . add_modifier(
            (
                UnitStatModifier
                . create(
                    &"combat_strength",
                    &"effect:combat_strength",
                    CombatStats.STATS.Strength,
                    UnitStatModifier.OPERATION.FLAT_ADD,
                    10.0,
                )
            )
        )
    )
    await _test_stat_effects(unit, strength)
    await _test_effect_manager(unit, strength)
    await _test_effect_request_correlation(unit)
    await _test_round_effect_lifecycle(unit)
    await _test_animation_fallback(unit)
    await free_node(unit)
    await _test_defensive_grants()


## Attribute caps constrain only the calculated base. Real equipment/effects and
## persistent passive-ledger grants must exceed it and revoke independently.
func _test_defensive_grants() -> void:
    for stat_id in [
        CombatStats.STATS.PhysicalResistance,
        CombatStats.STATS.MagicResistance,
        CombatStats.STATS.Evasion,
        CombatStats.STATS.LuckyEvasion
    ]:
        var unit := BattleUnit.create(CELINE_TEMPLATE)
        add_child(unit)
        assert(BattleEquipmentLoadout.capture(unit).is_empty(), "Opening rough clothing grants no armor.")
        unit.get_stat(CombatStats.STATS.Experience).set_base(1800)
        var stat := unit.get_stat(stat_id) as UnitGenericScalingStat
        var definition := stat.original_template as UnitScaleddStatTemplate
        var influence := unit.get_stat(definition.influenced_by)
        influence.set_base(1000)
        assert(is_equal_approx(stat.Base, definition.maximum))
        var equip_effect := _defense_effect(
            stat_id, &"equipment_defense", 12.0, EffectTemplate.LIFETIME.WHILE_SOURCE_ACTIVE
        )
        var equipment := EquipmentTemplate.new()
        equipment.id = &"test_defensive_equipment"
        equipment.equips_to = [UnitEquipmentSlot.SLOT.LeftHand]
        equipment.on_equip_effects = [equip_effect]
        assert(await unit.equip_item(equipment, UnitEquipmentSlot.SLOT.LeftHand) != null)
        stat.add_modifier(
            UnitStatModifier.create(
                &"defensive_passive",
                &"skill:test_defense",
                stat_id,
                UnitStatModifier.OPERATION.FLAT_ADD,
                15.0,
                UnitStatModifier.LIFETIME.PERSISTENT
            )
        )
        unit.add_effect(
            unit, unit, _defense_effect(stat_id, &"active_defense", 18.0, EffectTemplate.LIFETIME.UNTIL_BATTLE_END)
        )
        assert(
            is_equal_approx(stat.Current, definition.maximum + 45.0),
            "Direct defensive grants must exceed the attribute-derived cap."
        )
        influence.set_base(10)
        stat.recalculate()
        stat.recalculate()
        assert(
            stat.Base < definition.maximum and is_equal_approx(stat.Current, stat.Base + 45.0),
            "Dependency changes rebuild the base without clamping or duplicating direct grants."
        )
        unit.effect_manager.remove_battle_scoped_effects()
        assert(is_equal_approx(stat.Current, stat.Base + 27.0))
        await unit.unequip_item(UnitEquipmentSlot.SLOT.LeftHand)
        assert(is_equal_approx(stat.Current, stat.Base + 15.0))
        stat.remove_modifiers_from_source(&"skill:test_defense")
        assert(is_equal_approx(stat.Current, stat.Base))
        await free_node(unit)
    var harlok := BattleUnit.create(
        load("res://GrimDaysBattle/resources/units/harlok/harlok_battle_unit_template.tres")
    )
    add_child(harlok)
    assert(BattleEquipmentLoadout.capture(harlok).is_empty(), "Harlok's rough clothing has no armor grants either.")
    await free_node(harlok)


## Builds a temporary defensive-stat effect for the grant/removal regression checks.
func _defense_effect(
    stat_id: CombatStats.STATS, effect_id: StringName, amount: float, lifetime: EffectTemplate.LIFETIME
) -> EffectFlatChangeStatTemplate:
    var effect := EffectFlatChangeStatTemplate.new()
    effect.id = effect_id
    effect.stat = stat_id
    effect.flat_amount = amount
    effect.lifetime = lifetime
    effect.trigger = CombatEffects.TRIGGER.EQUIP
    effect.kind = CombatEffects.KIND.BUFF
    effect.template_scene = STAT_EFFECT_SCENE
    return effect


## Checks stat effects using test objects and assertions. A failed assertion identifies behavior
## that no longer meets the test’s expectation.
func _test_stat_effects(unit: BattleUnit, strength: UnitGenericStat) -> void:
    var flat_template := EffectFlatChangeStatTemplate.new()
    flat_template.id = &"effect_strength_flat"
    flat_template.stat = CombatStats.STATS.Strength
    flat_template.flat_amount = 3.0
    flat_template.lifetime = EffectTemplate.LIFETIME.WHILE_SOURCE_ACTIVE
    var flat_effect := EffectStatChange.new()
    flat_effect.name = flat_template.id
    flat_effect.setup(unit, unit, flat_template)
    add_child(flat_effect)
    flat_effect.apply()
    assert(flat_effect.finished, "A synchronous stat effect must complete immediately.")
    assert(is_equal_approx(strength.Current, 25.3), "Flat stat effects must grant a source-owned modifier.")
    await _remove_effect(flat_effect)
    assert(is_equal_approx(strength.Current, 22.0), "Removing a stat effect must reverse only its modifier.")
    var percent_template := EffectPercentageChangeStatTemplate.new()
    percent_template.id = &"effect_strength_percent"
    percent_template.stat = CombatStats.STATS.Strength
    percent_template.percentage = 0.25
    percent_template.lifetime = EffectTemplate.LIFETIME.WHILE_SOURCE_ACTIVE
    var percent_effect := EffectStatChange.new()
    percent_effect.name = percent_template.id
    percent_effect.setup(unit, unit, percent_template)
    add_child(percent_effect)
    percent_effect.apply()
    assert(is_equal_approx(strength.Current, 27.0), "Percentage stat effects must use fractional additive percentages.")
    percent_effect.apply()
    assert(is_equal_approx(strength.Current, 27.0), "Applying the same effect twice must not duplicate its modifier.")
    await _remove_effect(percent_effect)
    assert(is_equal_approx(strength.Current, 22.0), "Percentage modifier cleanup must restore the prior value.")


## Checks effect manager using test objects and assertions. A failed assertion identifies behavior
## that no longer meets the test’s expectation.
func _test_effect_manager(unit: BattleUnit, strength: UnitGenericStat) -> void:
    assert(not unit.effect_manager.has_effects_to_trigger(CombatEffects.TRIGGER.PROCESS_OVER))
    assert(not unit.effect_manager.has_effects_to_trigger(CombatEffects.TRIGGER.ROUND_OVER))
    var template := EffectFlatChangeStatTemplate.new()
    template.id = &"managed_equipment_strength"
    template.stat = CombatStats.STATS.Strength
    template.flat_amount = 4.0
    template.lifetime = EffectTemplate.LIFETIME.WHILE_SOURCE_ACTIVE
    template.kind = CombatEffects.KIND.ONCE
    template.trigger = CombatEffects.TRIGGER.EQUIP
    template.template_scene = STAT_EFFECT_SCENE
    unit.effect_manager.add_effect(unit, unit, template)
    assert(is_equal_approx(strength.Current, 26.4), "The effect manager must route and apply equip stat effects.")
    var battle_template := EffectFlatChangeStatTemplate.new()
    battle_template.id = &"battle_scoped_strength"
    battle_template.stat = CombatStats.STATS.Strength
    battle_template.flat_amount = 2.0
    battle_template.lifetime = EffectTemplate.LIFETIME.UNTIL_BATTLE_END
    battle_template.kind = CombatEffects.KIND.BUFF
    battle_template.trigger = CombatEffects.TRIGGER.EQUIP
    battle_template.template_scene = STAT_EFFECT_SCENE
    unit.effect_manager.add_effect(unit, unit, battle_template)
    var persistent_template := EffectFlatChangeStatTemplate.new()
    persistent_template.id = &"persistent_strength"
    persistent_template.stat = CombatStats.STATS.Strength
    persistent_template.flat_amount = 1.0
    persistent_template.lifetime = EffectTemplate.LIFETIME.PERSISTENT
    persistent_template.kind = CombatEffects.KIND.BUFF
    persistent_template.trigger = CombatEffects.TRIGGER.EQUIP
    persistent_template.template_scene = STAT_EFFECT_SCENE
    unit.effect_manager.add_effect(unit, unit, persistent_template)
    assert(is_equal_approx(strength.Current, 29.7))
    unit.effect_manager.remove_battle_scoped_effects()
    assert(
        is_equal_approx(strength.Current, 27.5),
        "Battle cleanup must remove UNTIL_BATTLE_END grants immediately.",
    )
    unit.effect_manager.remove_effects_from_sender(unit)
    await get_tree().process_frame
    assert(
        is_equal_approx(strength.Current, 22.0),
        "Source removal must reverse WHILE_SOURCE_ACTIVE and explicitly removed persistent grants.",
    )


## Checks round effect lifecycle using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_round_effect_lifecycle(attacker: BattleUnit) -> void:
    var target := create_unit()
    var health := create_flat_stat(target, CombatStats.STATS.Health, 100.0)
    var template := make_scaled_template(
        &"round_true_damage_test",
        CombatStats.STATS.PhysicalDamage,
        -0.25,
        CombatDamage.TYPE.True,
    )
    template.duration = 2
    template.lifetime = EffectTemplate.LIFETIME.ROUNDS
    template.kind = CombatEffects.KIND.REPEAT
    template.trigger = CombatEffects.TRIGGER.ROUND_OVER
    target.effect_manager.add_effect(attacker, target, template)
    var holder: EffectDirectors = target.effect_manager.triggers_to_holders[CombatEffects.TRIGGER.ROUND_OVER]
    var effect: EffectScaledStatChange = holder.incoming_effect
    var damage_events: Array[int]
    var on_damaged := func(damaged_unit: BattleUnit, amount: int) -> void:
        if damaged_unit == target:
            damage_events.append(amount)
    SignalBus.damaged.connect(on_damaged)
    await target.resolve_effects(CombatEffects.TRIGGER.ROUND_OVER)
    assert(is_equal_approx(health.Current, 90.0))
    assert(effect.duration == 2 and effect.ticked)
    await target.resolve_effects(CombatEffects.TRIGGER.ROUND_OVER)
    assert(is_equal_approx(health.Current, 90.0), "Round effects must apply at most once per round.")
    assert(effect.duration == 2, "Triggering must not consume a round-based lifetime.")
    SignalBus.tick.emit(&"legacy_round_boundary")
    assert(not effect.ticked, "The round boundary must make surviving effects eligible again.")
    assert(effect.duration == 1, "Round lifetimes must decrease at the round boundary.")
    await target.resolve_effects(CombatEffects.TRIGGER.ROUND_OVER)
    assert(is_equal_approx(health.Current, 80.0))
    assert(damage_events == [10, 10])
    SignalBus.tick.emit(&"legacy_round_boundary")
    await get_tree().process_frame
    assert(holder.get_children().is_empty(), "An effect must expire after its final authored round.")
    SignalBus.damaged.disconnect(on_damaged)
    await free_node(target)


## Checks effect request correlation using test objects and assertions. A failed assertion
## identifies behavior that no longer meets the test’s expectation.
func _test_effect_request_correlation(unit: BattleUnit) -> void:
    var completed: Array[StringName] = []
    var capture := func(request_id: StringName) -> void: completed.append(request_id)
    unit.effects_triggered.connect(capture)
    var first := await unit.resolve_effects(CombatEffects.TRIGGER.PROCESS_OVER, &"action:first")
    var second := await unit.resolve_effects(CombatEffects.TRIGGER.PROCESS_OVER, &"action:second")
    assert(first != second)
    assert(String(first).begins_with("action:first:effects:"))
    assert(String(second).begins_with("action:second:effects:"))
    assert(
        completed == [first, second],
        "Effect completions must preserve the exact request identity and order.",
    )
    unit.effects_triggered.disconnect(capture)


## Checks animation fallback using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_animation_fallback(unit: BattleUnit) -> void:
    var template := EffectTemplateTriggerAnimation.new()
    template.id = &"headless_animation_test"
    template.animation_id = &"attack_"
    var effect := EffectTriggerAnimation.new()
    effect.name = template.id
    effect.setup(unit, unit, template)
    add_child(effect)
    effect.apply()
    assert(effect.finished, "Animation effects must complete immediately when no display is attached.")
    await _remove_effect(effect)
    var correlated_effect := EffectTriggerAnimation.new()
    var other_target := BattleUnit.new()
    correlated_effect.targeting = unit
    correlated_effect.animation_id = &"attack_right"
    correlated_effect.request_id = &"animation:test:1"
    correlated_effect.on_animation_played(other_target, &"attack_right", &"animation:test:1")
    correlated_effect.on_animation_played(unit, &"attack_right", &"animation:test:stale")
    assert(not correlated_effect.finished, "Unrelated animation completions must be ignored.")
    correlated_effect.on_animation_played(unit, &"attack_right", &"animation:test:1")
    assert(correlated_effect.finished, "The matching animation request must finish its effect.")
    other_target.free()
    correlated_effect.free()


## Removes the effect and waits until its node leaves the scene tree.
func _remove_effect(effect: EffectBase) -> void:
    effect.remove()
    await effect.tree_exited
