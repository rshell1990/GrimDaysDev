extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"


## Runs the damage smoke checks. Creates or uses test objects and stops on failed assertions.
func run() -> void:
    var attacker := create_unit()
    attacker.randomizer.set_seed(1234)
    var expected_rng := RandomNumberGenerator.new()
    expected_rng.seed = 1234
    var physical_damage := roundf(45.0 * expected_rng.randf_range(0.85, 1.15))
    var magic_damage := roundf(30.0 * expected_rng.randf_range(0.7, 1.3))
    create_flat_stat(attacker, CombatStats.STATS.PhysicalDamage, 40.0)
    create_flat_stat(attacker, CombatStats.STATS.MagicDamage, 50.0)
    create_flat_stat(attacker, CombatStats.STATS.DamageModifier, 1.5)
    var target := create_unit()
    var health := create_flat_stat(target, CombatStats.STATS.Health, 100.0)
    create_flat_stat(target, CombatStats.STATS.PhysicalResistance, 25.0)
    create_flat_stat(target, CombatStats.STATS.MagicResistance, 40.0)
    var physical_template := make_scaled_template(
        &"physical_damage_test",
        CombatStats.STATS.PhysicalDamage,
        -1.0,
        CombatDamage.TYPE.Physical,
    )
    physical_template.scales_with_damage = true
    physical_template.lifetime = EffectTemplate.LIFETIME.WHILE_SOURCE_ACTIVE
    target.effect_manager.add_effect(attacker, target, physical_template)
    var physical_effect: EffectScaledStatChange = (
        target.effect_manager.triggers_to_holders[CombatEffects.TRIGGER.TARGETED].incoming_effect
    )
    await target.effect_manager.trigger_effects(CombatEffects.TRIGGER.TARGETED)
    assert(physical_effect.finished, "Managed damage effects must signal completion.")
    assert(is_equal_approx(physical_effect.raw_change, -60.0))
    assert(is_equal_approx(physical_effect.mitigation_percent, 25.0))
    assert(is_equal_approx(physical_effect.resolved_change, physical_damage))
    assert(
        is_equal_approx(health.Current, 100.0 - physical_damage), "Physical resistance must mitigate physical damage."
    )
    assert(target.last_hit_by == attacker, "Health damage must record the attacking unit.")
    target.effect_manager.remove_effects_from_sender(attacker)
    await get_tree().process_frame
    var magic_effect := apply_scaled_effect(
        attacker,
        target,
        make_scaled_template(
            &"magic_damage_test",
            CombatStats.STATS.MagicDamage,
            -1.0,
            CombatDamage.TYPE.Magic,
        )
    )
    assert(is_equal_approx(magic_effect.resolved_change, magic_damage))
    assert(
        is_equal_approx(health.Current, 100.0 - physical_damage - magic_damage),
        "Magic resistance must mitigate magical damage."
    )
    await _remove_effect(magic_effect)
    health.restore_current(25.0)
    var rng_before_true := attacker.randomizer.random_number_generator.state
    var true_effect := apply_scaled_effect(
        attacker,
        target,
        make_scaled_template(
            &"true_damage_test",
            CombatStats.STATS.PhysicalDamage,
            -0.5,
            CombatDamage.TYPE.True,
        )
    )
    assert(attacker.randomizer.random_number_generator.state == rng_before_true)
    assert(is_zero_approx(true_effect.mitigation_percent))
    assert(is_equal_approx(true_effect.resolved_change, 20.0))
    assert(is_equal_approx(health.Current, 5.0), "True damage must bypass both resistances.")
    await _remove_effect(true_effect)
    var healing_effect := apply_scaled_effect(
        attacker,
        target,
        make_scaled_template(
            &"scaled_healing_test",
            CombatStats.STATS.MagicDamage,
            0.5,
            CombatDamage.TYPE.None,
        )
    )
    assert(is_equal_approx(healing_effect.resolved_change, 25.0))
    assert(is_equal_approx(health.Current, 30.0), "Positive scaling must restore the target stat.")
    await _remove_effect(healing_effect)
    var overkill_effect := apply_scaled_effect(
        attacker,
        target,
        make_scaled_template(
            &"overkill_test",
            CombatStats.STATS.PhysicalDamage,
            -1.0,
            CombatDamage.TYPE.True,
        )
    )
    assert(is_equal_approx(overkill_effect.resolved_change, 30.0), "Damage must report actual health lost.")
    assert(is_zero_approx(health.Current), "Damage must clamp the target stat to zero.")
    await _remove_effect(overkill_effect)
    # Compare the seeded variance draw followed by the critical draw, including RNG state.
    create_flat_stat(attacker, CombatStats.STATS.CriticalStrike, 50.0)
    create_flat_stat(attacker, CombatStats.STATS.Luck, 0.0)
    create_flat_stat(attacker, CombatStats.STATS.Level, 1.0)
    for damage_type in [CombatDamage.TYPE.Physical, CombatDamage.TYPE.Magic]:
        for roll_seed in range(8):
            health.restore_current(100.0)
            attacker.randomizer.set_seed(roll_seed)
            expected_rng.seed = roll_seed
            var variance := (
                expected_rng.randf_range(0.85, 1.15)
                if damage_type == CombatDamage.TYPE.Physical
                else expected_rng.randf_range(0.7, 1.3)
            )
            var expected_critical := expected_rng.randf_range(0.0, 100.0) < 50.0
            var expected_damage := 10.0 * variance * (2.0 if expected_critical else 1.0)
            expected_damage *= 0.75 if damage_type == CombatDamage.TYPE.Physical else 0.6
            var critical_template := make_scaled_template(
                &"variance_critical", CombatStats.STATS.PhysicalDamage, -0.25, damage_type
            )
            critical_template.can_critical = true
            var critical_effect := apply_scaled_effect(attacker, target, critical_template)
            assert(critical_effect.critical_hit == expected_critical)
            assert(is_equal_approx(critical_effect.resolved_change, roundf(expected_damage)))
            assert(attacker.randomizer.random_number_generator.state == expected_rng.state)
            await _remove_effect(critical_effect)
    await free_node(target)
    await free_node(attacker)


## Removes the effect and waits until its node leaves the scene tree.
func _remove_effect(effect: EffectBase) -> void:
    effect.remove()
    await effect.tree_exited
