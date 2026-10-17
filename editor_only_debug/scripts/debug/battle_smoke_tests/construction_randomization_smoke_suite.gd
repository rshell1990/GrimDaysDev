extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"

## Script loaded for template validator; reused instead of looking up the file on each call.
const TEMPLATE_VALIDATOR := preload(
    "res://GrimDaysBattle/scripts/Unit/Resources/battle_unit_template_validator.gd"
)


## Runs the construction randomization smoke checks. Creates or uses test objects and stops on
## failed assertions.
func run() -> void:
    await _test_attribute_authoring_helper()
    _test_template_validation()
    await _test_registered_unit_construction()
    await _test_template_starting_level()
    await _test_seeded_randomization()


## Checks template validation using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_template_validation() -> void:
    var valid_errors: PackedStringArray = TEMPLATE_VALIDATOR.validate(CELINE_TEMPLATE)
    assert(valid_errors.is_empty(), "Celine must pass battle preflight validation: %s" % valid_errors)

    var invalid_template := BattleUnitTemplate.new()
    invalid_template.id = &"InvalidDuplicateUnit"
    invalid_template.stats = UnitStatTemplateCollection.new()
    var first_health := UnitStatTemplate.new()
    first_health.type = CombatStats.STATS.Health
    first_health.id = &"Health"
    var second_health := UnitStatTemplate.new()
    second_health.type = CombatStats.STATS.Health
    second_health.id = &"Health"
    invalid_template.stats.all = [first_health, second_health]
    var invalid_errors: PackedStringArray = TEMPLATE_VALIDATOR.validate(invalid_template)
    assert(_contains_error(invalid_errors, "duplicate stat id"))
    assert(_contains_error(invalid_errors, "duplicate stat type"))
    assert(_contains_error(invalid_errors, "must use UnitCalculatedStatTemplate"))

    var cyclic_template := BattleUnitTemplate.new()
    cyclic_template.id = &"CyclicUnit"
    cyclic_template.stats = UnitStatTemplateCollection.new()
    var curve := Curve.new()
    curve.add_point(Vector2.ZERO)
    var health := UnitCalculatedStatTemplate.new()
    health.type = CombatStats.STATS.Health
    health.id = &"Health"
    health.influenced_by = CombatStats.STATS.Mana
    health.growth_curve = curve
    var mana := UnitCalculatedStatTemplate.new()
    mana.type = CombatStats.STATS.Mana
    mana.id = &"Mana"
    mana.influenced_by = CombatStats.STATS.Health
    mana.growth_curve = curve
    cyclic_template.stats.all = [health, mana]
    assert(_contains_error(TEMPLATE_VALIDATOR.validate(cyclic_template), "cyclic stat dependency"))


## Checks registered unit construction using test objects and assertions. A failed assertion
## identifies behavior that no longer meets the test’s expectation.
func _test_registered_unit_construction() -> void:
    var unit := BattleUnit.create(CELINE_TEMPLATE)
    assert(unit, "A preflight-valid registered unit must construct through BattleUnitCreation.")
    add_child(unit)
    for required_type in TEMPLATE_VALIDATOR.REQUIRED_COMBAT_STATS:
        var stat := unit.get_stat(required_type)
        assert(stat, "Constructed unit is missing %s." % CombatStats.get_stat_as_string(required_type))
        assert(
            is_finite(stat.Base) and is_finite(stat.Min) and is_finite(stat.Max) and is_finite(stat.Current),
            "Constructed stat %s must be finite." % stat.name,
        )
    assert(unit.get_stat(CombatStats.STATS.Health) is UnitGenericCalculatedStat)
    assert(unit.get_stat(CombatStats.STATS.Accuracy) is UnitGenericScalingStat)
    assert(unit.get_stat(CombatStats.STATS.WeightLimit) is UnitWeightLimitStat)
    assert(unit.get_stat(CombatStats.STATS.Encumberance) is UnitEncumberanceStat)
    assert(
        unit.get_chance_to_hit() == roundi(unit.get_stat(CombatStats.STATS.Accuracy).Current),
        "Accuracy is already authored on the 0-100 scale and must not be multiplied by 100.",
    )
    await free_node(unit)


## Starting XP must establish the requested level before progression grants.
func _test_template_starting_level() -> void:
    for starting_level in [0, 3, 10]:
        var template := CELINE_TEMPLATE.duplicate() as BattleUnitTemplate
        template.level = starting_level
        var unit := BattleUnit.create(template, false)
        assert(unit)
        assert(unit.get_stat(CombatStats.STATS.Experience).Base == starting_level * 600)
        assert(is_equal_approx(unit.level, starting_level))
        assert(unit.attribute_progression.highest_level == starting_level)
        var grants := BattleAttributeProgression.grants(unit, starting_level)
        assert(BattleAttributeProgression.snapshot(unit).earned == grants)
        add_child(unit)
        await free_node(unit)

    # External nested Resources can remain shared after duplicate(true). Own the
    # collection and Level definition before changing an authored starting offset.
    var offset_template := CELINE_TEMPLATE.duplicate() as BattleUnitTemplate
    offset_template.stats = CELINE_TEMPLATE.stats.duplicate() as UnitStatTemplateCollection
    offset_template.stats.all = CELINE_TEMPLATE.stats.all.duplicate()
    offset_template.level = 3
    var authored_level: UnitCalculatedStatTemplate
    var authored_offset := 0.0
    for index in offset_template.stats.all.size():
        var stat_template := offset_template.stats.all[index]
        if stat_template.type == CombatStats.STATS.Level:
            authored_level = stat_template
            authored_offset = authored_level.starting_amount
            offset_template.stats.all[index] = stat_template.duplicate()
            offset_template.stats.all[index].starting_amount = 1.0
    var offset_unit := BattleUnit.create(offset_template, false)
    assert(offset_unit)
    assert(offset_unit.get_stat(CombatStats.STATS.Experience).Base == 1200)
    assert(is_equal_approx(offset_unit.level, 3.0))
    assert(offset_unit.attribute_progression.highest_level == 3)
    add_child(offset_unit)
    await free_node(offset_unit)
    assert(
        authored_level.starting_amount == authored_offset,
        "Offset fixtures must not change the shared authored Level definition for later suites."
    )


## Checks seeded randomization using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_seeded_randomization() -> void:
    var first := UnitRandomizationControl.new()
    var second := UnitRandomizationControl.new()
    first.name = "FirstRandomizer"
    second.name = "SecondRandomizer"
    add_child(first)
    add_child(second)
    first.set_seed(8675309)
    second.set_seed(8675309)
    var first_sequence: Array[bool] = []
    var second_sequence: Array[bool] = []
    for index in 12:
        first_sequence.append(first.percentage_roll(37.0))
        second_sequence.append(second.percentage_roll(37.0))
    assert(first_sequence == second_sequence, "Equal seeds must produce equal combat roll sequences.")
    first.set_seed(8675309)
    second.set_seed(8675309)
    var candidates: Array = [&"first", &"second", &"third"]
    var first_targets: Array = []
    var second_targets: Array = []
    for index in 12:
        first_targets.append(first.pick_random(candidates))
        second_targets.append(second.pick_random(candidates))
    assert(first_targets == second_targets, "Equal seeds must produce equal random target sequences.")
    assert(not first.roll(0.0), "A 0% chance must always fail, even with pity ready.")
    assert(first.roll(100.0), "A 100% chance must always succeed.")
    # Find a reproducible run of failures, then compare stream positions to prove no retries occur.
    var probe := RandomNumberGenerator.new()
    var failure_seed: int = -1
    for candidate in range(1000):
        probe.seed = candidate
        var all_fail := true
        for attempt in 7:
            all_fail = (probe.randf_range(0, 100) >= 1.0) and all_fail
        if all_fail:
            failure_seed = candidate
            break
    assert(failure_seed >= 0)
    first.set_seed(failure_seed)
    probe.seed = failure_seed
    var pity_events: Array = []
    var on_pity := func(unit): pity_events.append(unit)
    SignalBus.pity_triggered.connect(on_pity)
    for attempt in 6:
        assert(not first.roll(1.0))
        probe.randf_range(0, 100)
        assert(first.fails == attempt + 1)
        assert(first.random_number_generator.state == probe.state, "Each ordinary roll draws exactly once.")
    assert(pity_events.is_empty())
    assert(not first.roll(0.0) and first.fails == 6)
    assert(first.roll(1.0) and first.fails == 0 and pity_events.size() == 1)
    assert(first.random_number_generator.state == probe.state, "Pity does not reroll.")
    assert(not first.roll(1.0) and first.fails == 1, "Pity cannot remain latched after success.")
    assert(first.roll(100.0) and first.fails == 0)
    first.fails = 5
    assert(first.percentage_roll(100.0) and first.fails == 0)
    # A natural success below the pity threshold also clears the streak.
    first.set_seed(failure_seed)
    probe.seed = failure_seed
    var winning_chance := (probe.randf_range(0, 100) + 100.0) / 2.0
    first.fails = 5
    assert(first.roll(winning_chance) and first.fails == 0)
    assert(pity_events.size() == 1)
    SignalBus.pity_triggered.disconnect(on_pity)
    await free_node(first)
    await free_node(second)


## Returns whether any error contains the requested text, ignoring letter case.
func _contains_error(errors: PackedStringArray, expected: String) -> bool:
    for error in errors:
        if expected.to_lower() in error.to_lower():
            return true
    return false


## Rerolls preserve resource identity, conserve pools, survive saving, and cannot double-spend grants.
func _test_attribute_authoring_helper() -> void:
    var template := CELINE_TEMPLATE.duplicate() as BattleUnitTemplate
    # Own the fixture resources: the helper intentionally edits its existing references.
    template.stats = CELINE_TEMPLATE.stats.duplicate() as UnitStatTemplateCollection
    template.stats.all = CELINE_TEMPLATE.stats.all.duplicate()
    for index in template.stats.all.size():
        template.stats.all[index] = template.stats.all[index].duplicate() as UnitStatTemplate
    var original_stats := template.stats
    var original_resources := template.stats.all.duplicate()
    var original_paths := template.stats.all.map(func(stat): return stat.resource_path)
    var original_values := template.stats.all.map(func(stat): return stat.starting_amount)
    var rng := RandomNumberGenerator.new()
    rng.seed = 12345
    template.level = 1
    assert(template.randomize_attribute_points(rng))
    assert(_attribute_total(template) == 64, "48 starting + 12 combat + 4 non-combat breakthrough points.")
    assert(template.stats == original_stats)
    assert(template.stats.all == original_resources)
    assert(template.stats.all.map(func(stat): return stat.resource_path) == original_paths)
    for index in template.stats.all.size():
        if template.stats.all[index].type not in CombatStats.ATTRIBUTE_STATS:
            assert(template.stats.all[index].starting_amount == original_values[index])
    var first_values: Array = template.stats.all.map(func(stat): return stat.starting_amount)
    rng.seed = 12345
    assert(template.randomize_attribute_points(rng))
    assert(
        first_values == template.stats.all.map(func(stat): return stat.starting_amount),
        "Reroll must reset, not accumulate."
    )
    template.level = 3
    assert(template.randomize_attribute_points(rng))
    assert(_attribute_total(template) == 70, "Automatic combat and specialization growth must not be baked in.")
    assert(template.starting_attribute_points_spent == {"combat": 16, "non_combat": 6})
    var path := "user://attribute_authoring_smoke.tres"
    assert(ResourceSaver.save(template, path) == OK)
    var reloaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as BattleUnitTemplate
    assert(
        (
            _attribute_total(reloaded) == 70
            and reloaded.starting_attribute_points_spent == template.starting_attribute_points_spent
        )
    )
    assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK)
    var unit := BattleUnit.create(reloaded, false)
    assert(unit)
    add_child(unit)
    var snapshot := BattleAttributeProgression.snapshot(unit)
    assert(snapshot.available.combat == 0 and snapshot.available.non_combat == 0)
    var total := 0.0
    for stat_id in CombatStats.ATTRIBUTE_STATS:
        total += unit.get_stat(stat_id).Current
    assert(total == 92, "Runtime adds two levels of 8 ordinary + 3 specialization growth exactly once.")
    BattleAttributeProgression.restore(unit, unit.attribute_progression.duplicate(true))
    assert(BattleAttributeProgression.snapshot(unit).available.combat == 0)
    unit.get_stat(CombatStats.STATS.Experience).set_base(2400)
    assert(BattleAttributeProgression.snapshot(unit).available.combat == 2)
    assert(BattleAttributeProgression.snapshot(unit).available.non_combat == 1)
    await free_node(unit)
    # Isolate specialization from archetype weighting.
    template.unit_archetype = ""
    # Deterministic aggregate checks the preference without relying on a single roll.
    template.level = 0
    var specialized := 0.0
    var ordinary := 0.0
    for roll in 100:
        assert(template.randomize_attribute_points(rng))
        assert(_attribute_total(template) == 48)
        for stat in template.stats.all:
            if stat.type == CombatStats.STATS.Finesse:
                specialized += stat.starting_amount
            elif stat.type == CombatStats.STATS.Strength:
                ordinary += stat.starting_amount
    assert(specialized > ordinary * 2)
    # Check each authored archetype independently, then its overlap with specialization.
    template.leveling_tiers = LevelingTierDefinitionCollection.new()
    var tier := LevelingTierDefinition.new()
    tier.start_level = 1
    tier.end_level = 9
    template.leveling_tiers.all = [tier]
    var preferences := {
        "Warrior":
        [
            CombatStats.STATS.Strength,
            CombatStats.STATS.Vitality,
            CombatStats.STATS.Endurance,
            CombatStats.STATS.Perception
        ],
        "Mage":
        [
            CombatStats.STATS.Mysticism,
            CombatStats.STATS.Willpower,
            CombatStats.STATS.Perception,
            CombatStats.STATS.Finesse
        ],
        "Hybrid":
        [
            CombatStats.STATS.Strength,
            CombatStats.STATS.Mysticism,
            CombatStats.STATS.Vitality,
            CombatStats.STATS.Perception
        ],
    }
    for archetype in preferences:
        template.unit_archetype = archetype
        var totals := {}
        for roll in 100:
            assert(template.randomize_attribute_points(rng))
            assert(_attribute_total(template) == 48)
            for stat in template.stats.all:
                if stat.type in CombatStats.ATTRIBUTE_STATS:
                    totals[stat.type] = totals.get(stat.type, 0.0) + stat.starting_amount
        for stat_id in preferences[archetype]:
            assert(
                totals[stat_id] > totals[CombatStats.STATS.Luck] * 2,
                "Every archetype preference must receive higher weight."
            )
    template.unit_archetype = "Warrior"
    tier.specialization = [CombatStats.STATS.Strength]
    var overlap := 0.0
    var archetype_only := 0.0
    for roll in 100:
        assert(template.randomize_attribute_points(rng))
        for stat in template.stats.all:
            if stat.type == CombatStats.STATS.Strength:
                overlap += stat.starting_amount
            elif stat.type == CombatStats.STATS.Vitality:
                archetype_only += stat.starting_amount
    assert(overlap > archetype_only * 1.3, "Archetype and specialization preferences must stack.")
    assert(template.stats == original_stats and template.stats.all == original_resources)


func _attribute_total(template: BattleUnitTemplate) -> float:
    var total := 0.0
    for stat in template.stats.all:
        if stat.type in CombatStats.ATTRIBUTE_STATS:
            total += stat.starting_amount
    return total
