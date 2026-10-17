extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"


## Runs the stat model smoke checks. Creates or uses test objects and stops on failed assertions.
func run() -> void:
    await _test_cumulative_growth()
    var unit := create_unit(CELINE_TEMPLATE)
    var strength := create_flat_stat(unit, CombatStats.STATS.Strength, 10.0)
    create_flat_stat(unit, CombatStats.STATS.Level, 1.0)
    var zero_stat := create_flat_stat(unit, CombatStats.STATS.Luck, 0.0)
    assert(is_zero_approx(zero_stat.Current), "Legitimate zero-valued stats must not be forced to one.")
    (
        strength
        . add_modifier(
            (
                UnitStatModifier
                . create(
                    &"training_sword_strength",
                    &"equipment:training_sword:1",
                    CombatStats.STATS.Strength,
                    UnitStatModifier.OPERATION.FLAT_ADD,
                    5.0,
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
                    &"strength_training_percent",
                    &"skill:strength_training",
                    CombatStats.STATS.Strength,
                    UnitStatModifier.OPERATION.PERCENT_ADD,
                    0.10,
                    UnitStatModifier.LIFETIME.PERSISTENT,
                )
            )
        )
    )
    assert(is_equal_approx(strength.Current, 16.5), "Flat and percentage modifiers must use stable operation order.")
    strength.remove_modifiers_from_source(&"equipment:training_sword:1")
    assert(is_equal_approx(strength.Current, 11.0), "Removing equipment must retain skill modifiers.")
    assert(strength.get_modifiers_from_source(&"skill:strength_training").size() == 1)
    var calculated := create_calculated_stat(unit, 25.0)
    assert(
        is_equal_approx(calculated.Current, 135.0),
        (
            "Calculated stats must add starting_amount to cumulative gains; got %s from Strength %s."
            % [calculated.Current, strength.Current]
        ),
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
    assert(
        is_equal_approx(calculated.Current, 245.0),
        "Calculated stats must retain starting_amount after dependency changes."
    )
    calculated.restore_current(calculated.Max * 0.5)
    strength.remove_modifiers_from_source(&"effect:combat_strength")
    assert(is_equal_approx(calculated.Max, 135.0))
    assert(is_equal_approx(calculated.Current, 67.5), "Recalculation must preserve the pool's fill ratio.")
    var weight_template := UnitWeightLimitTemplate.new()
    weight_template.type = CombatStats.STATS.WeightLimit
    weight_template.id = &"WeightLimit"
    weight_template.starting_amount = 15.0
    weight_template.influenced_by = [CombatStats.STATS.Strength]
    weight_template.growth_curve = calculated.original_template.growth_curve
    var weight_limit := UnitWeightLimitStat.new()
    weight_limit.setup(weight_template, unit)
    unit.stat_dictionary[weight_template.id] = weight_limit
    assert(is_equal_approx(weight_limit.Current, 125.0))
    strength.remove_modifiers_from_source(&"skill:strength_training")
    assert(
        is_equal_approx(weight_limit.Current, 115.0),
        "WeightLimit must retain starting_amount after dependency changes."
    )
    var scaled := create_scaled_stat(unit)
    assert(
        is_equal_approx(scaled.Current, 75.0 * (5.0 / 11.0)),
        "Scaled stats must use current divided by the level threshold.",
    )
    (
        unit
        . get_stat(CombatStats.STATS.Endurance)
        . add_modifier(
            (
                UnitStatModifier
                . create(
                    &"endurance_cap_test",
                    &"effect:endurance_cap_test",
                    CombatStats.STATS.Endurance,
                    UnitStatModifier.OPERATION.FLAT_ADD,
                    20.0,
                )
            )
        )
    )
    assert(is_equal_approx(scaled.Current, 75.0), "Scaled stats must clamp to their configured maximum.")
    await free_node(unit)


## Nonconstant gains distinguish a sum of samples from a final-value lookup or
## multiplying the last sample. Rebuilds retain modifiers without compounding.
func _test_cumulative_growth() -> void:
    var unit := create_unit(CELINE_TEMPLATE)
    var strength := create_flat_stat(unit, CombatStats.STATS.Strength, 5.0)
    var health := create_calculated_stat(unit, 25.0)
    assert(is_equal_approx(health.Base, 75.0), "Five points granting ten each add fifty to starting_amount.")
    strength.set_base(0)
    assert(is_equal_approx(health.Base, 25.0), "Zero influence contributes no curve samples.")
    var definition := health.original_template as UnitCalculatedStatTemplate
    definition.growth_curve.set_point_value(0, 0)
    definition.growth_curve.set_point_value(1, 300)
    strength.set_base(5)
    # Gains 10 + 20 + 30 + 40 + 50, followed by the starting 25.
    assert(is_equal_approx(health.Base, 175.0))
    health.add_modifier(
        UnitStatModifier.create(&"flat", &"test:curve", health.id, UnitStatModifier.OPERATION.FLAT_ADD, 5)
    )
    health.add_modifier(
        UnitStatModifier.create(&"percent", &"test:curve", health.id, UnitStatModifier.OPERATION.PERCENT_ADD, 0.20)
    )
    assert(is_equal_approx(health.Max, 216.0), "Modifiers apply after cumulative gains and starting_amount.")
    health.recalculate()
    health.recalculate()
    assert(is_equal_approx(health.Base, 175.0) and is_equal_approx(health.Max, 216.0))
    strength.set_base(6)
    assert(is_equal_approx(health.Base, 235.0) and is_equal_approx(health.Max, 288.0))
    strength.set_base(5)
    assert(is_equal_approx(health.Max, 216.0), "Losing influence must remove only that point's contribution.")
    health.remove_modifiers_from_source(&"test:curve")
    assert(is_equal_approx(health.Max, 175.0))
    strength.set_base(5.5)
    assert(is_equal_approx(health.Base, 205.0), "Fractional influence receives a proportional next-point gain.")
    assert(is_equal_approx(definition.calculate_base(32), 5275.0), "Beyond the domain, endpoint gains continue.")
    assert(is_equal_approx(definition.calculate_base(-1), 25.0))
    var weight_template := UnitWeightLimitTemplate.new()
    weight_template.type = CombatStats.STATS.WeightLimit
    weight_template.id = &"WeightLimit"
    weight_template.starting_amount = 15
    weight_template.influenced_by = [CombatStats.STATS.Strength]
    weight_template.growth_curve = definition.growth_curve
    strength.set_base(5)
    var weight := UnitWeightLimitStat.new()
    weight.setup(weight_template, unit)
    unit.stat_dictionary[weight_template.id] = weight
    assert(is_equal_approx(weight.Base, 165.0), "WeightLimit also accumulates per-point gains.")
    strength.set_base(6)
    assert(is_equal_approx(weight.Base, 225.0))
    await free_node(unit)

    # Exercise the unchanged authored Health curve through the production factory.
    unit = BattleUnit.create(CELINE_TEMPLATE)
    add_child(unit)
    var vitality := unit.get_stat(CombatStats.STATS.Vitality)
    health = unit.get_stat(CombatStats.STATS.Health)
    definition = health.original_template as UnitCalculatedStatTemplate
    vitality.set_base(5)
    assert(
        is_equal_approx(health.Base, definition.starting_amount + 270.0),
        (
            "Expected 270 + offset from Vitality 5; got base %s, influence %s, offset %s, samples %s/%s."
            % [
                health.Base,
                vitality.Current,
                definition.starting_amount,
                definition.growth_curve.sample(1),
                definition.growth_curve.sample(5)
            ]
        )
    )
    vitality.set_base(6)
    assert(
        is_equal_approx(health.Base, definition.starting_amount + 300.0),
        "The authored 30-point plateau means thirty additional Health per Vitality, not thirty total."
    )
    var level := unit.get_stat(CombatStats.STATS.Level)
    unit.get_stat(CombatStats.STATS.Experience).set_base(1800)
    assert(is_equal_approx(level.Base, 3.0), "Level retains its direct total-XP lookup.")
    await free_node(unit)
