extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"


## Runs the stat state smoke checks. Creates or uses test objects and stops on failed assertions.
func run() -> void:
    await _test_swiftness_dependency_and_speed()
    await _test_scalar_modifiers_and_turn_order()
    await _test_fractional_pool_bounds()


## Exercises authored curves through the production factory, including modifier retention
## and the distinction between raw Swiftness and weight-adjusted BattleUnit.speed.
func _test_swiftness_dependency_and_speed() -> void:
    var templates: Array[BattleUnitTemplate] = [
        CELINE_TEMPLATE,
        load("res://GrimDaysBattle/resources/units/harlok/harlok_battle_unit_template.tres"),
    ]
    for template in templates:
        var unit := BattleUnit.create(template)
        assert(unit != null)
        add_child(unit)
        var stat := unit.get_stat(CombatStats.STATS.Swiftness)
        assert(stat is UnitGenericCalculatedStat and stat.name == &"Swiftness")
        assert(unit.stat_dictionary.has(&"Swiftness") and not unit.stat_dictionary.has(&"Speed"))
        var definition := stat.original_template as UnitCalculatedStatTemplate
        assert(definition.influenced_by == CombatStats.STATS.Finesse)
        _override(unit, CombatStats.STATS.WeightLimit, 100)
        _override(unit, CombatStats.STATS.Weight, 0)
        _override(unit, CombatStats.STATS.Finesse, 1)
        assert(is_equal_approx(stat.Current, definition.starting_amount + definition.growth_curve.sample(1)))
        stat.add_modifier(
            UnitStatModifier.create(
                &"swiftness_bonus", &"test:swiftness", stat.id, UnitStatModifier.OPERATION.FLAT_ADD, 10
            )
        )
        _override(unit, CombatStats.STATS.Finesse, 500)
        var authored_total := definition.starting_amount
        for point in range(1, 501):
            authored_total += definition.growth_curve.sample(point)
        var raw_capacity := authored_total + 10
        assert(is_equal_approx(stat.Current, raw_capacity), "Finesse must recalculate without losing grants.")
        assert(unit.speed == snappedf(raw_capacity, 1))
        _override(unit, CombatStats.STATS.Weight, 100)
        assert(is_equal_approx(stat.Current, raw_capacity), "Weight must not modify raw Swiftness.")
        assert(unit.speed == maxf(snappedf(raw_capacity - snappedf(raw_capacity * 0.5, 1), 1), 1))
        stat.remove_modifiers_from_source(&"test:swiftness")
        assert(is_equal_approx(stat.Current, authored_total))
        _override(unit, CombatStats.STATS.Weight, 200)
        assert(unit.speed == 1)
        await free_node(unit)


## Adds a test-only stat adjustment that replaces the selected stat's value with the supplied
## amount.
func _override(unit: BattleUnit, stat_id: CombatStats.STATS, amount: float) -> void:
    unit.get_stat(stat_id).add_modifier(
        UnitStatModifier.create(&"state_override", &"test:state", stat_id, UnitStatModifier.OPERATION.OVERRIDE, amount)
    )


## Checks scalar modifiers and turn order using test objects and assertions. A failed assertion
## identifies behavior that no longer meets the test’s expectation.
func _test_scalar_modifiers_and_turn_order() -> void:
    var unit := BattleUnit.create(CELINE_TEMPLATE)
    var other := BattleUnit.create(CELINE_TEMPLATE)
    add_child(unit)
    add_child(other)
    _override(unit, CombatStats.STATS.WeightLimit, 100)
    _override(unit, CombatStats.STATS.Weight, 50)
    var enc := unit.get_stat(CombatStats.STATS.Encumberance)
    assert(enc.Current == 50 and enc.Max == 200)
    enc.add_modifier(UnitStatModifier.create(&"load", &"test:load", enc.id, UnitStatModifier.OPERATION.FLAT_ADD, 10))
    assert(enc.Current == 60 and enc.Max == 200, "Encumberance modifiers must not preserve a pool ratio.")
    _override(unit, CombatStats.STATS.Weight, 100)
    assert(enc.Current == 110)
    enc.remove_modifiers_from_source(&"test:load")
    assert(enc.Current == 100 and enc.Max == 200)
    _override(unit, CombatStats.STATS.Swiftness, 100)
    _override(other, CombatStats.STATS.Swiftness, 75)
    _override(other, CombatStats.STATS.Encumberance, 0)
    var order := BattleTurnOrder.new()
    order.begin_round([unit, other])
    assert(
        unit.speed == 50 and order.get_active_unit() == other, "Production turn order must include the weight penalty."
    )
    _override(unit, CombatStats.STATS.Weight, 0)
    enc.add_modifier(UnitStatModifier.create(&"load", &"test:load", enc.id, UnitStatModifier.OPERATION.FLAT_ADD, 10))
    assert(enc.Current == 10, "Zero-valued scalar stats must accept modifiers.")
    enc.remove_modifier(&"load")
    assert(enc.Current == 0)
    await free_node(unit)
    await free_node(other)


## Checks fractional pool bounds using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_fractional_pool_bounds() -> void:
    var unit := BattleUnit.create(CELINE_TEMPLATE)
    add_child(unit)
    _override(unit, CombatStats.STATS.Health, 10.75)
    var health := unit.get_stat(CombatStats.STATS.Health)
    health.increase_current_flat(100)
    assert(health.Current == 10.75)
    health.decrease_current_flat(0)
    assert(health.Current <= health.Max)
    health.change_min(0.25)
    health.decrease_current_flat(100)
    assert(health.Current == 0.25)
    health.restore_current(4.375)
    assert(health.Current == 4.375, "Restore must not quantize a saved resource pool.")
    await free_node(unit)
