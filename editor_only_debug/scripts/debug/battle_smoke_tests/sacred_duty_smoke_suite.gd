# Saved Sacred Duty resources exercised through progression, effects and production battle services.
extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/street_bullies_smoke_suite.gd"

const DEFINITION_SIGNATURE = preload(
    "res://GrimDaysBattle/scripts/Skills/Runtime/skill_definition_signature.gd"
)
const SACRED_ROOT = "res://GrimDaysBattle/resources/"
const SISTERS = ["hara", "katherine", "anastasia"]
const KNIFE = preload("res://GrimDaysBattle/resources/items/weapons/one_handed/ritual_knife.tres")
const NUN_RANKS = [
    {
        &"ritual_cut": 2,
        &"candlelight": 1,
        &"prayer_of_shelter": 1,
        &"steadfast_faith": 3,
        &"righteous_censure": 2,
        &"intercession": 3,
        &"righteous_resolve": 2
    },
    {
        &"ritual_cut": 1,
        &"candlelight": 1,
        &"measured_penance": 3,
        &"steadfast_faith": 2,
        &"righteous_censure": 1,
        &"righteous_resolve": 2
    },
    {
        &"ritual_cut": 1,
        &"candlelight": 2,
        &"small_mercy": 1,
        &"prayer_of_shelter": 2,
        &"steadfast_faith": 2,
        &"merciful_hands": 3,
        &"righteous_resolve": 1
    },
]
const SPECS = {
    "ritual_cut": [20, 3, 220, 0],
    "candlelight": [10, 2, 230, 1],
    "small_mercy": [18, 2, 230, 3],
    "prayer_of_shelter": [12, 2, 230, 2],
    "measured_penance": [25, 3, 220, 1],
    "righteous_censure": [18, 2, 230, 2],
    "intercession": [18, 2, 230, 2],
    "merciful_hands": [22, 2, 230, 3],
}


func run() -> void:
    _test_target_signature_compatibility()
    await _test_nun_defaults()
    for number in range(1, 6):
        await _test_sacred_rank(number)
        await _test_penance_proc(number, true)
        await _test_penance_proc(number, false)
    await _test_sacred_passives()
    await _test_ward_replacement()
    await _test_nun_choices()
    await _test_support_limits()
    await _test_actual_magic_pressure()
    print("SACRED_DUTY_SMOKE_SUITE: PASS") # lint:ignore debug-print -- Required test/CLI output.


func _nun_template(index: int) -> BattleUnitTemplate:
    var name: String = SISTERS[index]
    return load(SACRED_ROOT + "units/sister_%s/sister_%s_battle_unit_template.tres" % [name, name])


func _sacred_action(name: String) -> ActionTemplate:
    return load(SACRED_ROOT + "actions/sacred_duty/%s.tres" % name)


func _test_nun_defaults() -> void:
    for index in 3:
        var template := _nun_template(index)
        assert(template.skill_collection.validate().is_empty())
        var unit := BattleUnit.create(template)
        add_child(unit)
        assert(int(unit.level) == 5 and unit.skills.capture().ranks == NUN_RANKS[index])
        assert(unit.skills.snapshot().earned == [14, 18, 18][index])
        assert(unit.skills.snapshot().spent == [14, 10, 12][index])
        assert(unit.skills.snapshot().available == [0, 8, 6][index])
        assert(unit.get_stat(CombatStats.STATS.Health).Current == unit.get_stat(CombatStats.STATS.Health).Max)
        assert(
            (
                unit.get_stat(CombatStats.STATS.MagicDamage).Current
                < unit.get_stat(CombatStats.STATS.PhysicalDamage).Current
            )
        )
        assert(unit.get_stat(CombatStats.STATS.Mana).Current >= [42, 18, 40][index])
        for label in ["Ritual Cut", "Candlelight", "Small Mercy", "Prayer of Shelter"]:
            var replaced: bool = (
                (index == 0 and label in ["Candlelight", "Prayer of Shelter"])
                or (index == 1 and label in ["Ritual Cut", "Candlelight"])
                or (index == 2 and label == "Small Mercy")
            )
            if replaced:
                assert(not _find_action(unit, label))
        var blade := _find_action(unit, "Measured Penance" if index == 1 else "Ritual Cut")
        assert(blade and unit.can_use_action(blade), unit.get_action_unavailable_reason(blade))
        var saved: Dictionary = JSON.parse_string(JSON.stringify(unit.skills.capture()))
        var checkpoint := BattleRetryCheckpoint.new()
        checkpoint.capture([unit])
        unit.get_stat(CombatStats.STATS.Health).restore_current(13)
        assert(unit.skills.refresh().is_empty())
        assert(is_equal_approx(unit.get_stat(CombatStats.STATS.Health).Current, 13))
        assert(unit.skills.reset_all_from_authorized_source(unit.skills.revision) == [14, 10, 12][index])
        assert(checkpoint.restore() and unit.skills.capture().ranks == NUN_RANKS[index])
        assert(unit.skills.restore(saved).is_empty())
        assert(unit.skills.restore({"version": 1, "ranks": {}}).is_empty())
        assert(unit.skills.refresh().is_empty() and unit.skills.snapshot().spent == 0)
        assert(template.skill_collection.default_assignment.ranks == NUN_RANKS[index])
        # Real level gates and replacement prerequisites reject invalid saved investments atomically.
        assert(not unit.skills.purchase({&"merciful_hands": 1}, unit.skills.revision).is_empty())
        _override_stat(unit, CombatStats.STATS.Level, 4)
        assert(not unit.skills.purchase({&"righteous_resolve": 1}, unit.skills.revision).is_empty())
        assert(unit.skills.snapshot().spent == 0)
        await free_node(unit)


func _test_sacred_rank(number: int) -> void:
    var f := _fixture(2)
    _prepare(f)
    _override_stat(f.actor, CombatStats.STATS.Accuracy, 100)
    _override_stat(f.actor, CombatStats.STATS.PhysicalDamage, 10)
    _override_stat(f.actor, CombatStats.STATS.MagicDamage, 10)
    await f.actor.equip_item(KNIFE, UnitEquipmentSlot.SLOT.LeftHand)
    for name in SPECS:
        var action := _sacred_action(name)
        var spec: Array = SPECS[name]
        _override_stat(
            f.actor,
            CombatStats.STATS.CriticalStrike,
            100 if action.type in [CombatActions.TYPE.MAGICAL, CombatActions.TYPE.HEAL] else 0
        )
        _override_stat(f.actor, CombatStats.STATS.DamageModifier, 2 if action.type == CombatActions.TYPE.HEAL else 1)
        assert(action.ranks.validate_progression().is_empty() and action.get_rank_count() == 5)
        var rank := action.get_rank_template(number)
        assert(rank.cost[spec[2]] == spec[0] + spec[1] * (number - 1))
        assert(rank.cooldown_turns == spec[3])
        assert(f.actor.grant_action_from_source(&"sacred_rank", action, number))
        var support: bool = action.target == CombatActions.TARGET.ALLY
        var target: BattleUnit = f.actor if support else f.foes[0]
        assert(CombatActions.valid_target(action, f.actor, target))
        assert(not CombatActions.valid_target(action, f.actor, f.foes[1]) if support else true)
        for stat in [CombatStats.STATS.Mana, CombatStats.STATS.Energy]:
            f.actor.get_stat(stat).restore_current(100)
        target.get_stat(CombatStats.STATS.Health).restore_current(50 if support else 100)
        var result: BattleActionResolution = await f.resolver.resolve(
            BattleActionRequest.new(StringName("sacred_%s_%s" % [name, number]), f.actor, action, [target])
        )
        assert(result.success, result.error)
        assert(is_equal_approx(f.actor.get_stat(spec[2]).Current, 100 - rank.cost[spec[2]]))
        if not support:
            var coefficient: float = (0.3 if action.type == CombatActions.TYPE.MAGICAL else 0.95) + number * 0.05
            assert(is_equal_approx(-rank.effects.all[0].scales_by, coefficient))
            assert(result.get_events(BattleCombatEvent.TYPE.DAMAGE).size() == 1)
            assert(
                is_equal_approx(
                    absf(result.get_events(BattleCombatEvent.TYPE.DAMAGE)[0].data.raw_change), 10 * coefficient
                )
            )
            if action.type == CombatActions.TYPE.MAGICAL:
                assert(not rank.effects.all[0].can_critical)
                assert(result.get_events(BattleCombatEvent.TYPE.CRITICAL).is_empty())
            if name == "righteous_censure":
                var status := _status(target, &"sacred_duty_censure")
                assert(status and is_equal_approx(status.source_template.percentage, -0.04 - number * 0.01))
        else:
            assert(result.get_events(BattleCombatEvent.TYPE.DAMAGE).is_empty())
            if name in ["small_mercy", "merciful_hands"]:
                assert(
                    is_equal_approx(target.get_stat(CombatStats.STATS.Health).Current, 50 + roundf(2.5 + number * 0.5))
                )
                assert(result.get_events(BattleCombatEvent.TYPE.HEALING).size() == 1)
                assert(result.get_events(BattleCombatEvent.TYPE.CRITICAL).is_empty())
            for effect in rank.effects.all:
                if effect is EffectPercentageChangeStatTemplate:
                    var status := _status(target, effect.id)
                    var potency: float = 0.04 + number * 0.02 if name == "merciful_hands" else 0.025 + number * 0.025
                    assert(status and status.duration == 2 and is_equal_approx(effect.percentage, potency))
        for turn in spec[3]:
            f.actor.on_turn_started()
            assert(not f.actor.can_use_action(action, true))
        if spec[3] > 0:
            f.actor.on_turn_started()
            assert(f.actor.can_use_action(action, true))
        if name in ["candlelight", "measured_penance", "righteous_censure"]:
            target.effect_manager.remove_battle_scoped_effects()
            _override_stat(f.actor, CombatStats.STATS.Accuracy, 0)
            var miss: BattleActionResolution = await f.resolver.resolve(
                BattleActionRequest.new(&"sacred_miss", f.actor, action, [target])
            )
            assert(miss.success and miss.get_events(BattleCombatEvent.TYPE.MISS).size() == 1)
            assert(not _status(target, &"sacred_duty_censure") and not _status(target, &"sacred_duty_penance_bleed"))
            assert(f.actor.get_action_cooldown(action) > 0)
            _override_stat(f.actor, CombatStats.STATS.Accuracy, 100)
        target.effect_manager.remove_battle_scoped_effects()
    # A bladed skill becomes unavailable when the authored weapon is removed.
    await f.actor.unequip_item(UnitEquipmentSlot.SLOT.LeftHand)
    assert(not f.actor.can_use_action(_sacred_action("ritual_cut"), true))
    await _free_fixture(f)


func _test_penance_proc(number: int, succeeds: bool) -> void:
    var f := _fixture(1)
    _prepare(f)
    _override_stat(f.actor, CombatStats.STATS.Accuracy, 100)
    _override_stat(f.actor, CombatStats.STATS.PhysicalDamage, 100)
    _override_stat(f.foes[0], CombatStats.STATS.Health, 1000)
    f.foes[0].get_stat(CombatStats.STATS.Health).restore_current(1000)
    await f.actor.equip_item(KNIFE, UnitEquipmentSlot.SLOT.LeftHand)
    var action := _sacred_action("measured_penance")
    assert(f.actor.grant_action_from_source(&"penance", action, number))
    var rider: EffectTriggerAnotherEffect = action.get_rank_template(number).effects.all[0].effects_on_hit[0]
    assert(rider.chance == [15, 18, 20, 23, 25][number - 1])
    var probe := RandomNumberGenerator.new()
    for candidate in range(100000):
        probe.seed = candidate
        probe.randf_range(0.85, 1.15)
        if (probe.randf_range(0, 100) < rider.chance) == succeeds:
            f.actor.randomizer.random_number_generator.seed = candidate
            break
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"penance_proc", f.actor, action, [f.foes[0]])
    )
    assert(result.success)
    var bleed := _status(f.foes[0], &"sacred_duty_penance_bleed") as EffectScaledStatChange
    assert((bleed != null) == succeeds)
    if bleed:
        assert(bleed.snapshot_ready and bleed.duration == 2)
        assert(is_equal_approx(bleed.snapshot_raw_change, -100 * (0.015 + number * 0.005)))
        assert(bleed.source_template.bypass_mitigation and bleed.source_template.always_hits)
        var frozen: float = bleed.snapshot_change
        _override_stat(f.actor, CombatStats.STATS.PhysicalDamage, 1000)
        _override_stat(f.actor, CombatStats.STATS.DamageModifier, 2)
        _override_stat(f.foes[0], CombatStats.STATS.PhysicalResistance, 1000)
        for tick in 2:
            var before: float = f.foes[0].get_stat(CombatStats.STATS.Health).Current
            await BattleEncounterEffects.new().end_round(f.scene.coordinator.roster, func(): return true)
            assert(
                is_equal_approx(f.foes[0].get_stat(CombatStats.STATS.Health).Current, before - roundf(absf(frozen))),
                (
                    "tick=%s before=%s after=%s frozen=%s removed=%s"
                    % [tick, before, f.foes[0].get_stat(CombatStats.STATS.Health).Current, frozen, bleed.removed]
                )
            )
        assert(not _status(f.foes[0], &"sacred_duty_penance_bleed"))
    await _free_fixture(f)


func _test_sacred_passives() -> void:
    var template := _nun_template(0).duplicate() as BattleUnitTemplate
    template.skill_collection = template.skill_collection.duplicate()
    template.skill_collection.default_assignment = null
    var unit := BattleUnit.create(template)
    add_child(unit)
    var health: float = unit.get_stat(CombatStats.STATS.Health).Max
    var resistance: float = unit.get_stat(CombatStats.STATS.MagicResistance).Current
    for number in range(1, 6):
        var saved := unit.skills.capture()
        saved.ranks = {"steadfast_faith": number, "righteous_resolve": number}
        var errors := unit.skills.restore(saved)
        assert(errors.is_empty(), str(errors))
        var multiplier: float = 1.025 + number * 0.025
        assert(is_equal_approx(unit.get_stat(CombatStats.STATS.Health).Max, health * multiplier))
        assert(is_equal_approx(unit.get_stat(CombatStats.STATS.MagicResistance).Current, resistance * multiplier))
    await free_node(unit)


func _test_ward_replacement() -> void:
    var f := _nun_fixture()
    var target: BattleUnit = f.foes[0]
    var baseline: float = target.get_stat(CombatStats.STATS.PhysicalResistance).Current
    var weak: EffectTemplate = _sacred_action("prayer_of_shelter").get_rank_template(1).effects.all[0]
    var strong: EffectTemplate = _sacred_action("intercession").get_rank_template(5).effects.all[0]
    var first := target.add_effect(f.foes[1], target, weak, {"source_id": &"ward_first"})
    first.apply()
    assert(is_equal_approx(target.get_stat(CombatStats.STATS.PhysicalResistance).Current, baseline * 1.05))
    target.effect_manager.advance_round()
    var second := target.add_effect(f.foes[2], target, strong, {"source_id": &"ward_second"})
    second.apply()
    assert(first.removed and second != first and second.duration == 2)
    assert(is_equal_approx(target.get_stat(CombatStats.STATS.PhysicalResistance).Current, baseline * 1.15))
    var third := target.add_effect(f.foes[1], target, weak, {"source_id": &"ward_third"})
    third.apply()
    assert(second.removed and third.duration == 2)
    assert(is_equal_approx(target.get_stat(CombatStats.STATS.PhysicalResistance).Current, baseline * 1.05))
    var checkpoint := BattleRetryCheckpoint.new()
    checkpoint.capture([target])
    target.effect_manager.advance_round()
    target.effect_manager.advance_round()
    assert(is_equal_approx(target.get_stat(CombatStats.STATS.PhysicalResistance).Current, baseline))
    assert(checkpoint.restore() and _status(target, weak.id).duration == 2)
    await _free_fixture(f)


func _nun_fixture() -> Dictionary:
    var party := IsolatedParty.new()
    add_child(party)
    var actor := BattleUnit.create(CELINE_TEMPLATE)
    party.add_child(actor)
    party.runtime_units[CELINE_TEMPLATE.id] = actor
    party.active_party_ids = [CELINE_TEMPLATE.id]
    var scene: BattleEncounterScene = ENCOUNTER.instantiate()
    add_child(scene)
    assert(scene.begin_encounter(party, [_nun_template(0), _nun_template(1), _nun_template(2)], &"sacred_duty", 2095))
    scene.flow.stop()
    var resolver := BattleActionResolver.new()
    add_child(resolver)
    return {
        "scene": scene,
        "party": party,
        "actor": actor,
        "foes": scene.coordinator.roster.get_foes(),
        "resolver": resolver
    }


func _test_nun_choices() -> void:
    var f := _nun_fixture()
    var hara: BattleUnit = f.foes[0]
    var katherine: BattleUnit = f.foes[1]
    var anastasia: BattleUnit = f.foes[2]
    var history: Array = []
    var first := SacredDutyAI.choose(hara, history)
    assert(first.action.display_name == "Intercession" and first.targets == [katherine])
    assert(SacredDutyAI.choose(katherine, history).action.display_name == "Measured Penance")
    var third := SacredDutyAI.choose(anastasia, history)
    assert(third.action.display_name == "Prayer of Shelter" and third.targets == [hara])
    for pair in [[hara, first], [anastasia, third]]:
        var result: BattleActionResolution = await f.resolver.resolve(
            BattleActionRequest.new(&"nun_opening", pair[0], pair[1].action, pair[1].targets)
        )
        assert(result.success, result.error)
        history.append_array(result.events)
    assert(SacredDutyAI.choose(hara, history).action.display_name == "Righteous Censure")
    # The ward on Katherine combines additively with her permanent resistance passive.
    assert(
        is_equal_approx(
            katherine.get_stat(CombatStats.STATS.MagicResistance).Current,
            katherine.get_stat(CombatStats.STATS.MagicResistance).Base * 1.175
        )
    )
    var hp := anastasia.get_stat(CombatStats.STATS.Health)
    hp.restore_current(hp.Max * 0.5)
    var heal := SacredDutyAI.choose(anastasia, history)
    assert(heal.action.display_name == "Merciful Hands" and heal.targets == [anastasia])
    var before: float = hp.Current
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"nun_self_heal", anastasia, heal.action, heal.targets)
    )
    assert(result.success and is_equal_approx(hp.Current, roundf(before + hp.Max * 0.04)))
    history.append_array(result.events)
    assert(SacredDutyAI.choose(anastasia, history).action.display_name != "Merciful Hands")
    for sister in f.foes:
        sister.get_stat(CombatStats.STATS.Mana).restore_current(0)
        sister.get_stat(CombatStats.STATS.Energy).restore_current(0)
        assert(SacredDutyAI.choose(sister, history).action == sister.get_basic_action())
    await _free_fixture(f)


func _test_support_limits() -> void:
    var f := _nun_fixture()
    var hara: BattleUnit = f.foes[0]
    var anastasia: BattleUnit = f.foes[2]
    var heal := _find_action(anastasia, "Merciful Hands")
    assert(CombatActions.valid_target(heal, anastasia, anastasia))
    assert(CombatActions.valid_target(heal, anastasia, hara))
    assert(not CombatActions.valid_target(heal, anastasia, f.actor))
    hara.get_stat(CombatStats.STATS.Health).restore_current(0)
    assert(not CombatActions.valid_target(heal, anastasia, hara))
    hara.get_stat(CombatStats.STATS.Health).restore_current(hara.get_stat(CombatStats.STATS.Health).Max - 1)
    var other_before: float = anastasia.get_stat(CombatStats.STATS.Health).Current
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"mercy_clamp", anastasia, heal, [hara])
    )
    assert(result.success and result.get_events(BattleCombatEvent.TYPE.HEALING).size() == 1)
    assert(hara.get_stat(CombatStats.STATS.Health).Current == hara.get_stat(CombatStats.STATS.Health).Max)
    assert(anastasia.get_stat(CombatStats.STATS.Health).Current == other_before)
    var magic := _status(hara, &"sacred_duty_magical_ward")
    assert(magic and is_equal_approx(magic.source_template.percentage, 0.1))
    var intercession: EffectTemplate = _sacred_action("intercession").get_rank_template(5).effects.all[1]
    var stronger := hara.add_effect(f.foes[1], hara, intercession, {"source_id": &"strong_intercession"})
    stronger.apply()
    assert(magic.removed and is_equal_approx(stronger.source_template.percentage, 0.15))
    var mercy: EffectTemplate = heal.get_rank_template(anastasia.get_action_rank(heal)).effects.all[1]
    var replaced := hara.add_effect(anastasia, hara, mercy, {"source_id": &"mercy_replacement"})
    replaced.apply()
    assert(stronger.removed and replaced.duration == 2)
    assert(
        is_equal_approx(
            hara.get_stat(CombatStats.STATS.MagicResistance).Current,
            hara.get_stat(CombatStats.STATS.MagicResistance).Base * 1.2
        )
    )
    # A player can replace potency downward, but the authored AI avoids wasting stronger wards.
    var shelter := _find_action(anastasia, "Prayer of Shelter")
    var strong_physical: EffectTemplate = _sacred_action("intercession").get_rank_template(5).effects.all[0]
    var physical := hara.add_effect(f.foes[1], hara, strong_physical, {"source_id": &"strong_physical"})
    physical.apply()
    assert(not SacredDutyAI._can_ward(hara, shelter, anastasia))
    # Existing ALLY actions still exclude self.
    assert(not CombatActions.valid_target(_gang_action("get_em"), anastasia, anastasia))
    await _free_fixture(f)


# Keep authored damage and Celine's mitigation; only force hits and prevent fixture defeat.
func _test_actual_magic_pressure() -> void:
    var f := _nun_fixture()
    _override_stat(f.actor, CombatStats.STATS.Health, 2000)
    f.actor.get_stat(CombatStats.STATS.Health).restore_current(2000)
    _override_stat(f.actor, CombatStats.STATS.Evasion, 0)
    _override_stat(f.actor, CombatStats.STATS.LuckyEvasion, 0)
    for index in 3:
        var sister: BattleUnit = f.foes[index]
        _override_stat(sister, CombatStats.STATS.Accuracy, 100)
        _override_stat(sister, CombatStats.STATS.CriticalStrike, 0)
        _override_stat(sister, CombatStats.STATS.Luck, 0)
        var blade := _find_action(sister, "Measured Penance" if index == 1 else "Ritual Cut")
        var spell := _find_action(sister, "Candlelight" if index == 2 else "Righteous Censure")
        sister.randomizer.random_number_generator.seed = 2095
        var strike: BattleActionResolution = await f.resolver.resolve(
            BattleActionRequest.new(&"actual_blade", sister, blade, [f.actor])
        )
        sister.randomizer.random_number_generator.seed = 2095
        var light: BattleActionResolution = await f.resolver.resolve(
            BattleActionRequest.new(&"actual_light", sister, spell, [f.actor])
        )
        assert(strike.success and light.success)
        assert(
            (
                light.get_events(BattleCombatEvent.TYPE.DAMAGE)[0].amount
                < strike.get_events(BattleCombatEvent.TYPE.DAMAGE)[0].amount
            )
        )
    await _free_fixture(f)


# Default-false targeting is absent from the fingerprint, matching pre-feature save definitions.
func _test_target_signature_compatibility() -> void:
    var old_action := _gang_action("get_em")
    var original := JSON.stringify(DEFINITION_SIGNATURE._value(old_action, []))
    assert(not original.contains("include_self"))
    var expanded := old_action.duplicate() as ActionTemplate
    expanded.include_self = true
    var changed := JSON.stringify(DEFINITION_SIGNATURE._value(expanded, []))
    assert(changed.contains("include_self") and changed != original)
