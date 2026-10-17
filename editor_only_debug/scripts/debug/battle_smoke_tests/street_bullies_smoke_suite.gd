# Exercises saved authored gang resources and fresh-unit defaults through the real battle services.
extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/combat_authoring_smoke_suite.gd"

const GANG_ROOT = "res://GrimDaysBattle/resources/"
const GANG_NAMES = ["harlok", "goon_a", "goon_b"]
const EXPECTED_RANKS = [
    {&"cheap_shot": 3, &"big_talk": 1, &"follow_up_elbow": 2, &"shoulder_check": 1, &"get_em": 1, &"thick_skin": 2},
    {&"cheap_shot": 3, &"big_talk": 2, &"follow_up_elbow": 2},
    {&"cheap_shot": 2, &"big_talk": 2, &"kick_dirt": 3},
]


func run() -> void:
    await _test_production_loadouts()
    await _test_default_assignments()
    await _test_assignment_rejection()
    for number in range(1, 6):
        await _test_authored_rank(number)
        await _test_delay(number, true)
        await _test_delay(number, false)
    await _test_shared_status()
    await _test_encounter_choices_and_combo()
    await _test_passive_ranks()
    print("STREET_BULLIES_SMOKE_SUITE: PASS") # lint:ignore debug-print -- Required test/CLI output.


# Copy production templates so test-specific changes do not edit shared resources.
func _gang_template(index: int) -> BattleUnitTemplate:
    var name: String = GANG_NAMES[index]
    var template: BattleUnitTemplate = load(GANG_ROOT + "units/%s/%s_battle_unit_template.tres" % [name, name]) # lint:ignore load-in-var,line-length -- Load fixtures during test execution.
    return template.duplicate() as BattleUnitTemplate


func _test_production_loadouts() -> void:
    for index in 3:
        var name: String = GANG_NAMES[index]
        var template: BattleUnitTemplate = load(GANG_ROOT + "units/%s/%s_battle_unit_template.tres" % [name, name]) # lint:ignore load-in-var,line-length -- Load fixtures during test execution.
        var unit := BattleUnit.create(template)
        add_child(unit)
        assert(unit.skills.capture().ranks == EXPECTED_RANKS[index])
        assert(unit.get_basic_action() != null)
        await free_node(unit)


func _gang_action(name: String) -> ActionTemplate:
    return load(GANG_ROOT + "actions/street_bullies/%s.tres" % name)


func _find_action(unit: BattleUnit, label: String) -> ActionTemplate:
    for action in unit.get_owned_actions():
        if action.display_name == label:
            return action
    return null


func _test_default_assignments() -> void:
    for index in 3:
        var template := _gang_template(index)
        assert(template.skill_collection.validate().is_empty())
        var original := template.skill_collection.default_assignment.ranks.duplicate()
        var unit := BattleUnit.create(template)
        add_child(unit)
        var twin := BattleUnit.create(template)
        add_child(twin)
        assert(unit.skills.capture().ranks == EXPECTED_RANKS[index])
        assert(unit.skills.snapshot().spent == [10, 7, 7][index])
        assert(unit.skills.snapshot().earned == [21, 12, 12][index])
        assert(unit.skills.snapshot().available == [11, 5, 5][index])
        assert(int(unit.level) == (3 if index == 0 else 2))
        assert(unit.get_stat(CombatStats.STATS.Health).Current == unit.get_stat(CombatStats.STATS.Health).Max)
        var combo := _find_action(unit, ["Shoulder Check", "Follow-Up Elbow", "Cheap Shot"][index])
        assert(combo != null)
        var rank := combo.get_rank_template(unit.get_action_rank(combo))
        assert(rank.cost[CombatStats.STATS.Energy] == [53, 48, 30][index])
        assert(rank.effects.all.size() == [3, 2, 1][index])
        if index == 0:
            assert(_find_action(unit, "Big Talk") == null and _find_action(unit, "Cheap Shot") == null)
            assert(_find_action(unit, "Get 'Em!") != null)
            var plain := template.duplicate() as BattleUnitTemplate
            plain.skill_collection = null
            var baseline := BattleUnit.create(plain)
            add_child(baseline)
            assert(
                is_equal_approx(
                    unit.get_stat(CombatStats.STATS.Health).Max, baseline.get_stat(CombatStats.STATS.Health).Max * 1.1
                )
            )
            await free_node(baseline)
        else:
            assert(_find_action(unit, "Shoulder Check") == null)
        # Refresh cannot duplicate grants or heal an injured unit.
        unit.get_stat(CombatStats.STATS.Health).restore_current(13)
        assert(unit.skills.refresh().is_empty())
        assert(is_equal_approx(unit.get_stat(CombatStats.STATS.Health).Current, 13))
        var saved: Dictionary = JSON.parse_string(JSON.stringify(unit.skills.capture()))
        var checkpoint := BattleRetryCheckpoint.new()
        checkpoint.capture([unit])
        assert(unit.skills.reset_all_from_authorized_source(unit.skills.revision) == [10, 7, 7][index])
        assert(unit.skills.refresh().is_empty() and unit.skills.snapshot().spent == 0)
        assert(twin.skills.capture().ranks == EXPECTED_RANKS[index])
        assert(checkpoint.restore())
        assert(unit.skills.capture().ranks == EXPECTED_RANKS[index])
        assert(unit.skills.restore(saved).is_empty())
        assert(unit.skills.restore({"version": 1, "ranks": {}}).is_empty())
        assert(unit.skills.refresh().is_empty() and unit.skills.snapshot().spent == 0)
        var invalid := saved.duplicate(true)
        invalid.ranks = {"unknown": 1}
        assert(not unit.skills.restore(invalid).is_empty())
        assert(unit.skills.snapshot().spent == 0)
        assert(template.skill_collection.default_assignment.ranks == original)
        await free_node(unit)
        await free_node(twin)


func _test_assignment_rejection() -> void:
    var collection := _gang_template(0).skill_collection.duplicate() as BattleSkillTreeCollection
    collection.default_assignment = BattleSkillDefaultAssignment.new()
    for ranks in [{&"unknown": 1}, {&"cheap_shot": 0}, {&"cheap_shot": 6}, {&"shoulder_check": 1}]:
        collection.default_assignment.ranks.assign(ranks)
        assert(not collection.validate().is_empty())
    collection.default_assignment.ranks.clear()
    assert(collection.validate().is_empty())
    var unit := BattleUnit.create(CELINE_TEMPLATE)
    add_child(unit)
    # Fresh adapters reject overspending and unavailable tiers atomically without publishing grants.
    for low_level in [false, true]:
        var adapter := BattleUnitSkills.new()
        add_child(adapter)
        collection.default_assignment.ranks.assign(EXPECTED_RANKS[0])
        if low_level:
            _override_stat(unit, CombatStats.STATS.Level, 1)
        else:
            unit.attribute_progression.highest_level = 0
        assert(not adapter.initialize(unit, collection).is_empty())
        assert(adapter.ledger.spent_points() == 0)
        unit.attribute_progression.highest_level = 3
        await free_node(adapter)
    await free_node(unit)


func _test_authored_rank(number: int) -> void:
    var f := _fixture(2)
    _prepare(f)
    _override_stat(f.actor, CombatStats.STATS.Accuracy, 100)
    var target: BattleUnit = f.foes[0]
    _override_stat(f.actor, CombatStats.STATS.PhysicalDamage, 10)
    for name in ["cheap_shot", "follow_up_elbow", "kick_dirt", "shoulder_check"]:
        var action := _gang_action(name)
        assert(action.ranks.validate_progression().is_empty() and action.get_rank_count() == 5)
        var rank := action.get_rank_template(number)
        var expected: Dictionary = {
            "cheap_shot": [1.0 + number * 0.05, 20 + number * 5],
            "follow_up_elbow": [0.35 + number * 0.05, 7 + number * 3],
            "kick_dirt": [0.35, 17 + number * 3],
            "shoulder_check": [0.2, 3 + number * 2]
        }
        assert(is_equal_approx(-rank.effects.all[0].scales_by, expected[name][0]))
        assert(rank.cost[CombatStats.STATS.Energy] == expected[name][1])
        assert(f.actor.grant_action_from_source(&"gang_test", action, number))
        f.actor.get_stat(CombatStats.STATS.Energy).restore_current(100)
        target.get_stat(CombatStats.STATS.Health).restore_current(100)
        var accuracy_before: float = target.get_stat(CombatStats.STATS.Accuracy).Current
        var result: BattleActionResolution = await f.resolver.resolve(
            BattleActionRequest.new(StringName("gang_rank_%s_%s" % [name, number]), f.actor, action, [target])
        )
        assert(result.success, result.error)
        assert(result.get_events(BattleCombatEvent.TYPE.DAMAGE).size() == 1)
        assert(
            is_equal_approx(
                absf(result.get_events(BattleCombatEvent.TYPE.DAMAGE)[0].data.raw_change), 10 * expected[name][0]
            )
        )
        assert(is_equal_approx(f.actor.get_stat(CombatStats.STATS.Energy).Current, 100 - expected[name][1]))
        assert(f.foes[1].get_stat(CombatStats.STATS.Health).Current == 100)
        if name == "kick_dirt":
            var penalty := rank.effects.all[0].effects_on_hit[0] as EffectPercentageChangeStatTemplate
            assert(is_equal_approx(penalty.percentage, -0.025 * (number + 1)))
            assert(_status(target, &"street_bullies_grit_in_the_eyes") != null)
            assert(
                is_equal_approx(
                    target.get_stat(CombatStats.STATS.Accuracy).Current, accuracy_before * (1 + penalty.percentage)
                )
            )
            target.effect_manager.remove_battle_scoped_effects()
            _override_stat(f.actor, CombatStats.STATS.Accuracy, 0)
            f.actor.get_stat(CombatStats.STATS.Energy).restore_current(100)
            result = await f.resolver.resolve(BattleActionRequest.new(&"dirt_miss", f.actor, action, [target]))
            assert(result.success and result.get_events(BattleCombatEvent.TYPE.MISS).size() == 1)
            assert(_status(target, &"street_bullies_grit_in_the_eyes") == null)
            _override_stat(f.actor, CombatStats.STATS.Accuracy, 100)
    # Avoid OVERRIDE modifiers for percentage tests: they deliberately override percent additions.
    var plain := BattleUnit.create(_gang_template(1))
    add_child(plain)
    var before_damage: float = plain.get_stat(CombatStats.STATS.DamageModifier).Current
    var before_resistance: float = plain.get_stat(CombatStats.STATS.PhysicalResistance).Current
    var talk := _gang_action("big_talk")
    assert(plain.grant_action_from_source(&"talk_rank", talk, number))
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"talk_rank", plain, talk, [plain])
    )
    assert(result.success, result.error)
    assert(
        is_equal_approx(
            plain.get_stat(CombatStats.STATS.DamageModifier).Current, before_damage * (1.025 + number * 0.025)
        )
    )
    var exposed := _status(plain, &"street_bullies_big_talk_exposed")
    assert(exposed != null and exposed.duration == 2)
    assert(plain.get_stat(CombatStats.STATS.PhysicalResistance).Current < before_resistance)
    plain.effect_manager.advance_round()
    assert(_status(plain, &"street_bullies_big_talk_damage") != null)
    plain.effect_manager.advance_round()
    assert(is_equal_approx(plain.get_stat(CombatStats.STATS.DamageModifier).Current, before_damage))
    await free_node(plain)
    await _free_fixture(f)


func _status(unit: BattleUnit, id: StringName) -> EffectBase:
    for holder in unit.effect_manager.triggers_to_holders.values():
        for child in holder.get_children():
            if child is EffectBase and child.id == id and not child.removed and not child.is_queued_for_deletion():
                return child
    return null


func _test_delay(number: int, succeeds: bool) -> void:
    var f := _fixture(3)
    _prepare(f)
    _override_stat(f.actor, CombatStats.STATS.Accuracy, 100)
    _override_stat(f.actor, CombatStats.STATS.Swiftness, 1000)
    var coordinator: BattleCoordinator = f.scene.coordinator
    assert(coordinator.begin_round(coordinator.session_id))
    assert(coordinator.record_turn_started(coordinator.session_id))
    var order := coordinator.turn_order.get_units()
    var target: BattleUnit = order[1]
    var action := _gang_action("shoulder_check")
    var chance: int = action.get_rank_template(number).effects.all[0].effects_on_hit[0].chance
    assert(chance == 5 + number * 5)
    assert(f.actor.grant_action_from_source(&"shoulder_test", action, number))
    # A physical strike samples variance before the on-hit chance (critical chance is zero).
    var probe := RandomNumberGenerator.new()
    var selected_seed: int = -1
    for candidate in range(100000):
        probe.seed = candidate
        probe.randf_range(0.8, 1.2)
        var sample := probe.randf_range(0, 100)
        if (succeeds and sample < chance) or (not succeeds and sample >= chance):
            selected_seed = candidate
            break
    f.actor.randomizer.random_number_generator.seed = selected_seed
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"shoulder_delay", f.actor, action, [target])
    )
    assert(result.success)
    assert(result.get_events(BattleCombatEvent.TYPE.TURN_DELAY).size() == (1 if succeeds else 0))
    var expected: Array = [order[0], order[2], order[1], order[3]] if succeeds else order
    assert(coordinator.turn_order.get_units() == expected)
    assert(coordinator.current_result.turns == 1)
    await _free_fixture(f)


func _test_shared_status() -> void:
    var f := _fixture(2)
    _prepare(f)
    _override_stat(f.actor, CombatStats.STATS.Accuracy, 100)
    var target: BattleUnit = f.foes[0]
    var definition: EffectTemplate = _gang_action("kick_dirt").get_rank_template(3).effects.all[0].effects_on_hit[0]
    var first := target.add_effect(f.actor, target, definition, {"source_id": &"first_goon"})
    target.effect_manager.advance_round()
    assert(first.duration == 1)
    var stronger: EffectTemplate = _gang_action("kick_dirt").get_rank_template(5).effects.all[0].effects_on_hit[0]
    var second := target.add_effect(f.foes[1], target, stronger, {"source_id": &"second_goon"})
    assert(is_equal_approx(second.source_template.percentage, -0.1))
    assert(first == second and first.duration == 2 and first.source_id == &"first_goon")
    var checkpoint := BattleRetryCheckpoint.new()
    checkpoint.capture([target])
    target.effect_manager.advance_round()
    target.effect_manager.advance_round()
    assert(_status(target, definition.id) == null)
    assert(checkpoint.restore())
    assert(_status(target, definition.id).duration == 2)
    var command := _gang_action("get_em")
    assert(not CombatActions.valid_target(command, f.actor, f.actor))
    assert(not CombatActions.valid_target(command, f.actor, target))
    assert(CombatActions.valid_target(command, f.foes[1], target))
    for number in range(1, 6):
        var rank := command.get_rank_template(number)
        assert(is_equal_approx(rank.effects.all[0].percentage, 0.075 + number * 0.025))
        assert(rank.cost[CombatStats.STATS.Energy] == 17 + number * 3)
        assert(f.foes[1].grant_action_from_source(&"command_test", command, number))
        f.foes[1].get_stat(CombatStats.STATS.Energy).restore_current(100)
        var result: BattleActionResolution = await f.resolver.resolve(
            BattleActionRequest.new(&"get_em_cast", f.foes[1], command, [target])
        )
        assert(result.success and result.get_events(BattleCombatEvent.TYPE.DAMAGE).is_empty())
        assert(_status(target, &"street_bullies_get_em_damage") != null)
        assert(
            is_equal_approx(
                target.get_stat(CombatStats.STATS.DamageModifier).Current,
                target.get_stat(CombatStats.STATS.DamageModifier).Base * (1.075 + number * 0.025)
            )
        )
        assert(_status(f.foes[1], &"street_bullies_get_em_damage") == null)
        target.effect_manager.remove_battle_scoped_effects()
    target.get_stat(CombatStats.STATS.Health).restore_current(0)
    assert(not CombatActions.valid_target(command, f.foes[1], target))
    assert(not f.foes[1].can_use_action(command, true))
    await _free_fixture(f)


func _fixture(count: int = 1) -> Dictionary:
    # Duplicate only the template and omit progression content irrelevant to these combat checks.
    var template := CELINE_TEMPLATE.duplicate() as BattleUnitTemplate
    template.skill_collection = null
    var party := IsolatedParty.new()
    add_child(party)
    var actor := BattleUnit.create(template)
    party.add_child(actor)
    party.runtime_units[template.id] = actor
    party.active_party_ids = [template.id]
    var templates: Array[BattleUnitTemplate] = []
    for index in count:
        templates.append(template)
    var scene: BattleEncounterScene = ENCOUNTER.instantiate()
    add_child(scene)
    assert(scene.begin_encounter(party, templates, &"ranked_modifiers", 515))
    scene.flow.stop()
    for unit in scene.coordinator.roster.get_participants():
        for stat in [CombatStats.STATS.Health, CombatStats.STATS.Mana, CombatStats.STATS.Energy]:
            unit.get_stat(stat).add_modifier(
                UnitStatModifier.create(
                    StringName("ranked_fixture:%s" % stat),
                    &"test:ranked_fixture",
                    stat,
                    UnitStatModifier.OPERATION.OVERRIDE,
                    100
                )
            )
            unit.get_stat(stat).restore_current(100)
    var resolver := BattleActionResolver.new()
    add_child(resolver)
    return {
        "scene": scene,
        "actor": actor,
        "foes": scene.coordinator.roster.get_foes(),
        "party": party,
        "resolver": resolver
    }


func _test_passive_ranks() -> void:
    var template := _gang_template(0).duplicate() as BattleUnitTemplate
    template.skill_collection = template.skill_collection.duplicate()
    template.skill_collection.default_assignment = null
    var unit := BattleUnit.create(template)
    add_child(unit)
    var base: float = unit.get_stat(CombatStats.STATS.Health).Max
    for number in range(1, 6):
        var saved := unit.skills.capture()
        saved.ranks = {"thick_skin": number}
        assert(unit.skills.restore(saved).is_empty())
        assert(is_equal_approx(unit.get_stat(CombatStats.STATS.Health).Max, base * (1 + 0.05 * number)))
    assert(unit.skills.restore({"version": 1, "ranks": {}}).is_empty())
    assert(is_equal_approx(unit.get_stat(CombatStats.STATS.Health).Max, base))
    await free_node(unit)


func _test_encounter_choices_and_combo() -> void:
    var party := IsolatedParty.new()
    add_child(party)
    var actor := BattleUnit.create(CELINE_TEMPLATE)
    party.add_child(actor)
    party.runtime_units[CELINE_TEMPLATE.id] = actor
    party.active_party_ids = [CELINE_TEMPLATE.id]
    var scene: BattleEncounterScene = ENCOUNTER.instantiate()
    add_child(scene)
    assert(
        scene.begin_encounter(
            party, [_gang_template(0), _gang_template(1), _gang_template(2)], &"street_bullies_choices", 177
        )
    )
    scene.flow.stop()
    var gang := scene.coordinator.roster.get_foes()
    var harlok: BattleUnit = gang[0]
    var goon_a: BattleUnit = gang[1]
    var goon_b: BattleUnit = gang[2]
    var resolver := BattleActionResolver.new()
    add_child(resolver)
    var history: Array = []
    var command := StreetBulliesAI.choose(harlok, history)
    assert(command.action.display_name == "Get 'Em!" and command.targets == [goon_a])
    assert(StreetBulliesAI.choose(goon_a, history).action.display_name == "Big Talk")
    assert(StreetBulliesAI.choose(goon_b, history).action.display_name == "Kick Dirt")
    var result: BattleActionResolution = await resolver.resolve(
        BattleActionRequest.new(&"harlok_opening", harlok, command.action, [goon_a])
    )
    assert(result.success, result.error)
    history.append_array(result.events)
    var combo_choice := StreetBulliesAI.choose(harlok, history)
    assert(combo_choice.action.display_name == "Shoulder Check", "Starting Energy must support the opening and combo.")
    var talk_choice := StreetBulliesAI.choose(goon_a, history)
    var base_damage: float = goon_a.get_stat(CombatStats.STATS.DamageModifier).Base
    result = await resolver.resolve(BattleActionRequest.new(&"goon_a_opening", goon_a, talk_choice.action, [goon_a]))
    assert(result.success)
    history.append_array(result.events)
    assert(is_equal_approx(goon_a.get_stat(CombatStats.STATS.DamageModifier).Current, base_damage * 1.175))
    assert(StreetBulliesAI.choose(goon_a, history).action.display_name == "Follow-Up Elbow")
    _override_stat(actor, CombatStats.STATS.Health, 2000)
    actor.get_stat(CombatStats.STATS.Health).restore_current(2000)
    for unit in gang:
        _override_stat(unit, CombatStats.STATS.Accuracy, 100)
        _override_stat(unit, CombatStats.STATS.CriticalStrike, 0)
        _override_stat(unit, CombatStats.STATS.Luck, 0)
        _override_stat(unit, CombatStats.STATS.PhysicalDamage, 10)
    _override_stat(actor, CombatStats.STATS.Evasion, 0)
    _override_stat(actor, CombatStats.STATS.LuckyEvasion, 0)
    var energy: float = harlok.get_stat(CombatStats.STATS.Energy).Current
    result = await resolver.resolve(BattleActionRequest.new(&"harlok_combo", harlok, combo_choice.action, [actor]))
    assert(result.success)
    assert(result.get_events(BattleCombatEvent.TYPE.DAMAGE).size() == 3)
    assert(result.get_events(BattleCombatEvent.TYPE.COST_PAID).size() == 1)
    assert(is_equal_approx(harlok.get_stat(CombatStats.STATS.Energy).Current, energy - 53))
    var damage := result.get_events(BattleCombatEvent.TYPE.DAMAGE)
    for index in 3:
        assert(is_equal_approx(absf(damage[index].data.raw_change), [11.5, 4.5, 2.0][index]))
    history.append_array(result.events)
    # Earlier hits cannot trigger Shoulder Check when the final strike misses.
    var miss_combo := combo_choice.action.duplicate(true) as ActionTemplate
    miss_combo.id = &"test_final_shoulder_miss"
    var miss_rank := miss_combo.get_rank_template(1)
    miss_rank.effects.all[0].always_hits = true
    miss_rank.effects.all[1].always_hits = true
    miss_rank.effects.all[2].effects_on_hit[0].chance = 100
    assert(harlok.grant_action_from_source(&"final_miss", miss_combo, 1))
    harlok.get_stat(CombatStats.STATS.Energy).restore_current(harlok.get_stat(CombatStats.STATS.Energy).Max)
    _override_stat(harlok, CombatStats.STATS.Accuracy, 0)
    result = await resolver.resolve(BattleActionRequest.new(&"final_miss", harlok, miss_combo, [actor]))
    assert(result.success and result.get_events(BattleCombatEvent.TYPE.DAMAGE).size() == 2)
    assert(result.get_events(BattleCombatEvent.TYPE.MISS).size() == 1)
    assert(result.get_events(BattleCombatEvent.TYPE.TURN_DELAY).is_empty())
    harlok.revoke_action_source(&"final_miss")
    _override_stat(harlok, CombatStats.STATS.Accuracy, 100)
    harlok.get_stat(CombatStats.STATS.Energy).restore_current(harlok.get_stat(CombatStats.STATS.Energy).Max)
    assert(harlok.can_use_action(combo_choice.action))
    # Real equipment blocks the entire composed unarmed chain.
    var dagger: EquipmentWeaponTemplate = load(GANG_ROOT + "items/weapons/one_handed/basic_dagger.tres") # lint:ignore load-in-var,line-length -- Load fixtures during test execution.
    await harlok.equip_item(dagger, UnitEquipmentSlot.SLOT.LeftHand)
    assert(not harlok.can_use_action(combo_choice.action))
    await harlok.unequip_item(UnitEquipmentSlot.SLOT.LeftHand)
    assert(harlok.can_use_action(combo_choice.action))
    # A missed dirt attempt still needs an intervening action; no status was attached.
    _override_stat(goon_b, CombatStats.STATS.Accuracy, 0)
    var dirt_choice := StreetBulliesAI.choose(goon_b, history)
    result = await resolver.resolve(BattleActionRequest.new(&"goon_b_miss", goon_b, dirt_choice.action, [actor]))
    assert(result.success and _status(actor, &"street_bullies_grit_in_the_eyes") == null)
    history.append_array(result.events)
    var next := StreetBulliesAI.choose(goon_b, history)
    assert(next.action.display_name == "Big Talk")
    result = await resolver.resolve(BattleActionRequest.new(&"goon_b_boast", goon_b, next.action, [goon_b]))
    assert(result.success)
    history.append_array(result.events)
    goon_b.get_stat(CombatStats.STATS.Energy).restore_current(goon_b.get_stat(CombatStats.STATS.Energy).Max)
    _override_stat(goon_b, CombatStats.STATS.Accuracy, 100)
    dirt_choice = StreetBulliesAI.choose(goon_b, history)
    assert(dirt_choice.action.display_name == "Kick Dirt")
    result = await resolver.resolve(BattleActionRequest.new(&"goon_b_hit", goon_b, dirt_choice.action, [actor]))
    assert(result.success and _status(actor, &"street_bullies_grit_in_the_eyes") != null)
    history.append_array(result.events)
    assert(StreetBulliesAI.choose(goon_b, history).action.display_name != "Kick Dirt")
    # Depleted units fall back without spending another support turn.
    harlok.get_stat(CombatStats.STATS.Energy).restore_current(0)
    assert(StreetBulliesAI.choose(harlok, history).action == harlok.get_basic_action())
    harlok.get_stat(CombatStats.STATS.Energy).restore_current(harlok.get_stat(CombatStats.STATS.Energy).Max)
    goon_a.get_stat(CombatStats.STATS.Health).restore_current(0)
    assert(StreetBulliesAI.choose(harlok, []).targets == [goon_b])
    goon_b.get_stat(CombatStats.STATS.Health).restore_current(0)
    assert(StreetBulliesAI.choose(harlok, []).action.display_name == "Shoulder Check")
    await _free_fixture({"scene": scene, "party": party, "resolver": resolver})
