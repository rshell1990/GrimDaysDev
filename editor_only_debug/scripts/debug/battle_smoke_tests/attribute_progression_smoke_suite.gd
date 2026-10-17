extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"
## Tier boundaries, spending, persistence, retries and the authored Apply controls.

const PROGRESSION := preload("res://GrimDaysBattle/scripts/Unit/Runtime/battle_attribute_progression.gd")


## Runs the progression, persistence, allocation, milestone and UI checks on test units. Assertions
## stop the suite if behavior differs.
func run() -> void:
    await _test_defense_investment()
    var party: BattlePartyManager = BattleController.party_manager
    await _test_story_milestone(party)
    var saved := party._get_state()
    var unit: BattleUnit = party.get_available_units()[0]
    var id := unit.template_resource.id
    var xp := unit.get_stat(CombatStats.STATS.Experience)
    var strength := unit.get_stat(CombatStats.STATS.Strength)
    var initial := strength.Current
    assert(party.get_attribute_points(id).available.combat == 0)
    # Authored XP curve is 600 XP/level. Start grants do not include per-level pools.
    xp.set_base(600)
    var state := party.get_attribute_points(id)
    assert(state.available == {"combat": 12, "non_combat": 4, "skill": 15})
    assert(strength.Current == initial)
    assert(unit.get_stat(CombatStats.STATS.Finesse).Current == unit.get_stat(CombatStats.STATS.Finesse).Base)
    # Reject mixed valid/invalid requests atomically, wrong pools and old revisions.
    for invalid in [
        {CombatStats.STATS.Strength: -1},
        {CombatStats.STATS.Strength: 1.5},
        {CombatStats.STATS.Strength: 1, CombatStats.STATS.Charisma: 5},
        {CombatStats.STATS.Experience: 1},
        {CombatStats.STATS.Strength: 13}
    ]:
        assert(not party.spend_attribute_points(id, invalid, state.revision))
    assert(strength.Current == initial)
    assert(party.acquire_encounter(self))
    assert(not party.spend_attribute_points(id, {CombatStats.STATS.Strength: 1}, state.revision))
    party.release_encounter(self)
    assert(
        party.spend_attribute_points(id, {CombatStats.STATS.Strength: 2, CombatStats.STATS.Charisma: 1}, state.revision)
    )
    assert(not party.spend_attribute_points(id, {CombatStats.STATS.Strength: 2}, state.revision))
    assert(strength.Current == initial + 2)
    assert(party.get_attribute_points(id).available.combat == 10)
    # Skipping levels awards each grant once, including automatic specialization.
    xp.set_base(1800)
    state = party.get_attribute_points(id)
    assert(state.available == {"combat": 14, "non_combat": 5, "skill": 21})
    assert(strength.Current == initial + 4)
    xp.set_base(600)
    xp.set_base(1800)
    assert(party.get_attribute_points(id) == state)
    # Temporary Level bonuses never earn permanent points.
    var level := unit.get_stat(CombatStats.STATS.Level)
    level.add_modifier(
        UnitStatModifier.create(
            &"test_level", &"test", CombatStats.STATS.Level, UnitStatModifier.OPERATION.FLAT_ADD, 20
        )
    )
    assert(party.get_attribute_points(id) == state)
    level.remove_modifier(&"test_level")
    # Tier end is inclusive; no grants leak into uncovered levels.
    assert(PROGRESSION.grants(unit, 9).combat == 28)
    assert(PROGRESSION.grants(unit, 10).combat == 28)
    _test_tiers(unit)
    # Retry restores both the watermark and modifiers, even after transient XP.
    var checkpoint := BattleRetryCheckpoint.new()
    checkpoint.capture([unit])
    xp.set_base(3600)
    assert(party.get_attribute_points(id).available.combat > state.available.combat)
    assert(checkpoint.restore())
    assert(party.get_attribute_points(id) == state)
    assert(strength.Current == initial + 4)
    # Actual JSON roundtrip, including JSON's numeric values and string keys.
    var data: Dictionary = party._get_state()
    data.units[id].attribute_progression = JSON.parse_string(JSON.stringify(data.units[id].attribute_progression))
    party.restore(data)
    unit = party.runtime_units[id]
    assert(unit.get_stat(CombatStats.STATS.Strength).Current == initial + 4)
    assert(party.get_attribute_points(id).available == state.available)
    party.restore(data)
    unit = party.runtime_units[id]
    assert(unit.get_stat(CombatStats.STATS.Strength).Current == initial + 4)
    await _test_panel(party, id)
    # Legacy saves omit the new ledger and receive current-level tier grants once.
    var legacy := party._get_state()
    legacy.units[id].erase("attribute_progression")
    party.restore(legacy)
    assert(party.get_attribute_points(id).available.combat == 16)
    assert(party.runtime_units[id].get_stat(CombatStats.STATS.Strength).Current == initial + 2)
    party.restore(saved)


## Opening defenses require competing allocations, not free caps from automatic
## tier growth. Accuracy/critical curves, progression and damage formulas stay intact.
func _test_defense_investment() -> void:
    var builds := {
        "baseline": {},
        "evasion": {CombatStats.STATS.Finesse: 16},
        "resistance": {CombatStats.STATS.Endurance: 16},
        "split": {CombatStats.STATS.Finesse: 8, CombatStats.STATS.Endurance: 8},
        "damage": {CombatStats.STATS.Strength: 16}
    }
    var values := {}
    for build in builds:
        var unit := BattleUnit.create(CELINE_TEMPLATE)
        add_child(unit)
        unit.get_stat(CombatStats.STATS.Experience).set_base(1800)
        var points := PROGRESSION.snapshot(unit)
        assert(points.available.combat == 16)
        if not builds[build].is_empty():
            assert(PROGRESSION.spend(unit, builds[build], points.revision))
        values[build] = {
            "evasion": unit.get_stat(CombatStats.STATS.Evasion).Current,
            "resistance": unit.get_stat(CombatStats.STATS.PhysicalResistance).Current,
            "damage": unit.get_stat(CombatStats.STATS.PhysicalDamage).Current
        }
        assert(is_equal_approx(unit.get_stat(CombatStats.STATS.Health).Max, 420.0))
        assert(is_equal_approx(unit.get_stat(CombatStats.STATS.Accuracy).Current, 78.75))
        assert(is_equal_approx(unit.get_stat(CombatStats.STATS.LuckyEvasion).Current, 0.5))
        assert(is_equal_approx(unit.get_stat(CombatStats.STATS.MagicResistance).Current, 2.4))
        assert(is_equal_approx(unit.get_stat(CombatStats.STATS.CriticalStrike).Current, 21.25))
        await free_node(unit)
    assert(is_equal_approx(values.baseline.evasion, 20.0 * 12.0 / 31.0))
    assert(is_equal_approx(values.baseline.resistance, 35.0 * 9.0 / 31.0))
    assert(is_equal_approx(values.evasion.evasion, 20.0 * 28.0 / 31.0))
    assert(is_equal_approx(values.resistance.resistance, 35.0 * 25.0 / 31.0))
    assert(values.split.evasion < values.evasion.evasion)
    assert(values.split.resistance < values.resistance.resistance)
    assert(
        is_equal_approx(values.split.damage, 50.0) and is_equal_approx(values.damage.damage, 130.0),
        "Spending the same budget on both defenses must forgo damage investment."
    )
    var evasion_curve := ( # lint:ignore load-in-var -- Load fixtures during test execution.
        load("res://GrimDaysBattle/resources/stats/scaling/evasion_threshold_level_1_to_9.tres") as Curve
    )
    var resistance_curve := ( # lint:ignore load-in-var -- Load fixtures during test execution.
        load("res://GrimDaysBattle/resources/stats/scaling/physical_resistance_threshold_level_1_to_9.tres")
        as Curve
    )
    var magic_curve := ( # lint:ignore load-in-var -- Load fixtures during test execution.
        load("res://GrimDaysBattle/resources/stats/scaling/magic_resistance_threshold_level_1_to_9.tres")
        as Curve
    )
    var lucky_curve := ( # lint:ignore load-in-var -- Load fixtures during test execution.
        load("res://GrimDaysBattle/resources/stats/scaling/lucky_evasion_threshold_level_1_to_9.tres")
        as Curve
    )
    for level in [1, 3, 9]:
        assert(is_equal_approx(evasion_curve.sample(level), 35.0 + 5.0 * level))
        assert(is_equal_approx(resistance_curve.sample(level), 35.0 + 5.0 * level))
        assert(is_equal_approx(magic_curve.sample(level), 35.0 + 5.0 * level))
        assert(is_equal_approx(lucky_curve.sample(level), 25.0 + 5.0 * level))
    for template_path in ["celine_teen/celine", "harlok/harlok", "goon_a/goon_a", "goon_b/goon_b"]:
        var template := ( # lint:ignore load-in-var -- Load fixtures during test execution.
            load("res://GrimDaysBattle/resources/units/%s_battle_unit_template.tres" % template_path)
            as BattleUnitTemplate
        )
        for stat in template.stats.all:
            if (
                template_path == "celine_teen/celine"
                and stat.type in [CombatStats.STATS.Evasion, CombatStats.STATS.PhysicalResistance]
            ):
                for level in [1, 3, 9]:
                    assert(is_equal_approx(stat.to_stat_maximum_curve.sample(level), 25.0 + 3.125 * (level - 1)))
                assert(stat.minimum == 0.0)
                assert(stat.maximum == (20.0 if stat.type == CombatStats.STATS.Evasion else 35.0))
                continue
            if stat.type == CombatStats.STATS.Evasion:
                assert(stat.to_stat_maximum_curve == evasion_curve)
            elif stat.type == CombatStats.STATS.PhysicalResistance:
                assert(stat.to_stat_maximum_curve == resistance_curve)
            elif stat.type == CombatStats.STATS.MagicResistance:
                assert(stat.to_stat_maximum_curve == magic_curve)
            elif stat.type == CombatStats.STATS.LuckyEvasion:
                assert(stat.to_stat_maximum_curve == lucky_curve)
            else:
                continue
            assert(stat.minimum == 0.0)
            assert(stat.maximum == (5.0 if stat.type == CombatStats.STATS.LuckyEvasion else 20.0))


## The office milestone awards a level floor, never additive XP, allocations or
## repeatable grants. Exercise the two actual authored Call lines without playing
## the preceding dialogue/cinematic or touching a player's save files.
func _test_story_milestone(party: BattlePartyManager) -> void:
    var saved := party._get_state()
    var original_state: GameManagerStates.STATES = GameManager.state
    var original_replay: bool = GameManager.in_replay
    var original_last_timeline: DialogicTimeline = Dialogic.last_timeline
    var id: StringName = CELINE_TEMPLATE.id
    var unit: BattleUnit = party.runtime_units[id]
    var xp := unit.get_stat(CombatStats.STATS.Experience)
    assert(CELINE_TEMPLATE.level == 0 and unit.get_stat(CombatStats.STATS.Level).Base == 0)
    assert(not party.ensure_minimum_level(&"unknown", 3))
    assert(not party.ensure_minimum_level(id, -1))
    assert(not party.ensure_minimum_level(id, 1000))
    assert(xp.Base == 0)
    assert(party.acquire_encounter(self))
    assert(not party.ensure_minimum_level(id, 3))
    party.release_encounter(self)
    var office := FileAccess.get_file_as_string(
        "res://GrimDaysVN/dialogic/scripts/2_0010_karak_seeks_scout_training.dtl"
    )
    var calls: Array = []
    for line in office.split("\n"):
        if (
            line.begins_with("do DialogicRelay.ensure_party_unit_level(")
            or line.begins_with("do UIDirector.show_story_party_preparation(")
        ):
            calls.append(line)
    assert(calls.size() == 2 and not office.contains("<< LEVELING SCREEN, NYI >>"))
    var timeline := DialogicTimeline.new()
    timeline.events = calls
    GameManager.state = GameManagerStates.STATES.Scenario
    Dialogic.start_timeline(timeline)
    var preparation := UIDirector._get_party_preparation()
    var deadline := Time.get_ticks_msec() + 5000
    while not preparation.active and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    assert(preparation.active, "The post-office milestone must present allocation UI.")
    assert(xp.Base == 1800 and unit.get_stat(CombatStats.STATS.Level).Base == 3)
    var before := party.get_attribute_points(id)
    assert(before.available == {"combat": 16, "non_combat": 6, "skill": 21})
    assert(before.allocated.is_empty(), "The player, not the milestone, distributes points.")
    assert(party.ensure_minimum_level(id, 3))
    assert(party.get_attribute_points(id) == before and xp.Base == 1800)
    assert(party.spend_attribute_points(id, {CombatStats.STATS.Strength: 1}, before.revision))
    preparation.cancel()
    await Dialogic.clear()
    var checkpoint: Dictionary = JSON.parse_string(JSON.stringify(party._get_state()))
    party.restore(checkpoint)
    assert(party.ensure_minimum_level(id, 3))
    assert(party.get_attribute_points(id).available.combat == 15)
    assert(party.get_attribute_points(id).allocated.Strength == 1)
    xp = party.runtime_units[id].get_stat(CombatStats.STATS.Experience)
    xp.set_base(2400)
    assert(party.ensure_minimum_level(id, 3) and xp.Base == 2400, "Revisiting cannot erase later XP.")
    GameManager.in_replay = true
    assert(not DialogicRelay.ensure_party_unit_level(String(id), 5))
    assert(xp.Base == 2400)
    GameManager.in_replay = original_replay
    assert(party.runtime_units[id].template_resource.level == 0)
    party.restore(saved)
    GameManager.state = original_state
    Dialogic.last_timeline = original_last_timeline


## Checks level-tier grants and growth, including boundaries and which templates receive NPC-only
## grants.
func _test_tiers(unit: BattleUnit) -> void:
    var original := unit.template_resource
    var template := original.duplicate() as BattleUnitTemplate
    var tiers := LevelingTierDefinitionCollection.new()
    var first := LevelingTierDefinition.new()
    first.start_level = 1
    first.end_level = 2
    first.combat_base_grant = 10
    first.combat_per_level = 2
    first.level_combat_growth = 1
    var second := LevelingTierDefinition.new()
    second.start_level = 3
    second.end_level = 4
    second.combat_base_grant = 20
    second.combat_per_level = 3
    second.non_combat_base_grant = 5
    second.skill_points_base_grant = 7
    second.level_combat_growth = 2
    second.specialization = [CombatStats.STATS.Strength]
    second.specialization_growth = 1
    tiers.all = [first, second]
    template.leveling_tiers = tiers
    # Use a separate unit so authored/runtime skill resources are not replaced.
    var fixture := BattleUnit.create(template, false)
    assert(PROGRESSION.grants(fixture, 2).combat == 12)
    var at_start := PROGRESSION.grants(fixture, 3)
    assert(at_start.combat == 32 and at_start.non_combat == 5 and at_start.skill == 7)
    assert(at_start.growth.Strength == 1, "Breakthrough must preserve earlier growth without adding new growth.")
    assert(PROGRESSION.grants(fixture, 1).growth.Strength == 0)
    assert(PROGRESSION.grants(fixture, 4).growth.Strength == 4)
    assert(PROGRESSION.grants(fixture, 4).growth.Vitality == 3)
    assert(PROGRESSION.grants(fixture, 5).growth == PROGRESSION.grants(fixture, 4).growth)
    assert(PROGRESSION.grants(fixture, 4).combat == 35)
    second.npc_only = true
    assert(PROGRESSION.grants(fixture, 4).combat == 12)
    fixture.free()


## Exercises attribute controls and Apply, including draft choices and rejection of outdated
## controls.
func _test_panel(party: BattlePartyManager, id: StringName) -> void:
    var previous_state: GameManagerStates.STATES = GameManager.state
    GameManager.state = GameManagerStates.STATES.Navigation
    assert(UIDirector.show_party_preparation())
    var session := UIDirector._get_party_preparation()
    var panel := session.panel
    var unit: BattleUnit = party.runtime_units[id]
    var before := unit.get_stat(CombatStats.STATS.Strength).Current
    var rows := panel.get_node(panel.ATTRIBUTE_ROWS)
    var strength := rows.get_node("Strength/Strength SpinBox") as SpinBox
    var charisma := rows.get_node("Charisma/Charisma SpinBox") as SpinBox
    var apply := rows.get_node("Spacer2/MarginContainer/Button") as Button
    assert(rows.get_node("Spacer2").visible and rows.get_node("Luck2").visible)
    strength.value += 2
    charisma.value += 1
    assert(unit.get_stat(CombatStats.STATS.Strength).Current == before, "Draft changes must not mutate stats.")
    assert(not apply.disabled)
    var old_apply: Callable = apply.pressed.get_connections()[0].callable
    apply.pressed.emit()
    assert(unit.get_stat(CombatStats.STATS.Strength).Current == before + 2)
    old_apply.call()
    assert(unit.get_stat(CombatStats.STATS.Strength).Current == before + 2)
    assert(apply.disabled)
    strength.value += 1
    panel._select_unit(id)
    assert(apply.disabled and panel._attribute_draft.is_empty())
    strength.value += 1
    old_apply = apply.pressed.get_connections()[0].callable
    session.close()
    old_apply.call()
    assert(unit.get_stat(CombatStats.STATS.Strength).Current == before + 2)
    GameManager.state = previous_state
    await get_tree().process_frame
