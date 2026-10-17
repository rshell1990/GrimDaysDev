# Exercises saved Uppercut ranks independently of unfinished skill-tree payloads.
extends "res://editor_only_debug/scripts/debug/ranked_effect_modifiers_smoke_test.gd"

const UPPERCUT_PATH = "res://GrimDaysBattle/resources/actions/celine/uppercut_single_rank/uppercut_single_rank.tres" # lint:ignore line-length -- Preserve resource path or authored text.
const NODE_PATH = "res://GrimDaysBattle/resources/skill_trees/celine/troubled_youth/tier 4/uppercut_node.tres"
const PUNCH_PATH = "res://GrimDaysBattle/resources/actions/celine/straight_punch/straight_punch.tres"


func _ready() -> void:
    # Load saved authoring at runtime instead of caching it as a script dependency.
    var action := load(UPPERCUT_PATH) as ActionTemplate # lint:ignore load-in-var,line-length -- Load fixtures during test execution.
    var node := load(NODE_PATH) as BattleSkillActionNode # lint:ignore load-in-var,line-length -- Load fixtures during test execution.
    assert(node.action == action and node.icon == action.icon and node.description == action.description)
    assert(action.ranks.get_rank_count() == 5 and action.ranks.validate_progression().is_empty())
    assert(action.equipment_requirements.is_empty())
    for number in range(1, 6):
        for outcome in ["critical", "ordinary", "miss"]:
            await _verify_outcome(action, number, outcome)
    await _verify_inherited_requirement(node)
    print("UPPERCUT_SMOKE_TEST: PASS") # lint:ignore debug-print -- Required test/CLI output.


func _verify_outcome(action: ActionTemplate, number: int, outcome: String) -> void:
    var rank := action.get_rank_template(number)
    var damage := rank.effects.all[0] as EffectScalingCombatStatChangeTemplate
    var coefficient: float = [1.5, 1.55, 1.625, 1.675, 1.725][number - 1]
    var bonus := 5.0 + (number - 1) * 2.5
    assert(rank.cost[CombatStats.STATS.Energy] == 15 + (number - 1) * 3)
    assert(damage.scales_with == CombatStats.STATS.PhysicalDamage)
    assert(is_equal_approx(damage.scales_by, -coefficient) and damage.critical_chance_bonus == bonus)
    assert(damage.effects_on_critical.size() == 1 and damage.effects_on_hit.is_empty())
    var stun := damage.effects_on_critical[0] as EffectStunTemplate
    assert(stun.duration == 1 and stun.lifetime == EffectTemplate.LIFETIME.ROUNDS)
    var f := _fixture(2)
    _prepare(f)
    _override_stat(f.actor, CombatStats.STATS.Accuracy, 0 if outcome == "miss" else 100)
    _override_stat(f.actor, CombatStats.STATS.PhysicalDamage, 10)
    _override_stat(f.actor, CombatStats.STATS.DamageModifier, 1)
    assert(f.actor.grant_action_from_source(&"uppercut_fixture", action, number))
    f.actor.randomizer.random_number_generator.seed = _critical_seed(bonus, outcome == "critical")
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"uppercut_check", f.actor, action, [f.foes[0]])
    )
    assert(result.success, result.error)
    assert(f.actor.get_stat(CombatStats.STATS.Energy).Current == 100 - rank.cost[CombatStats.STATS.Energy])
    assert(result.get_events(BattleCombatEvent.TYPE.CRITICAL).size() == (1 if outcome == "critical" else 0))
    var hits := result.get_events(BattleCombatEvent.TYPE.DAMAGE)
    assert(hits.size() == (0 if outcome == "miss" else 1))
    if outcome != "miss":
        assert(is_equal_approx(hits[0].data.raw_change, -10 * coefficient))
        assert(hits[0].target == f.foes[0])
    else:
        assert(result.get_events(BattleCombatEvent.TYPE.MISS).size() == 1)
    assert(f.foes[0].is_stunned() == (outcome == "critical"), "Critical stun must activate immediately.")
    assert(not f.actor.is_stunned() and not f.foes[1].is_stunned())
    assert(f.foes[1].get_stat(CombatStats.STATS.Health).Current == 100)
    f.foes[0].effect_manager.advance_round()
    assert(not f.foes[0].is_stunned(), "Uppercut stun ends at the next round boundary.")
    assert(f.actor.get_stat(CombatStats.STATS.CriticalStrike).Current == 0)
    await _free_fixture(f)


func _critical_seed(chance: float, critical: bool) -> int:
    var probe := RandomNumberGenerator.new()
    for candidate in range(100000):
        probe.seed = candidate
        # Physical variance is sampled before the strike's critical roll.
        probe.randf_range(0.85, 1.15)
        var sample := probe.randf_range(0, 100)
        if (
            (critical and sample >= chance - 1 and sample < chance)
            or (not critical and sample >= chance and sample < chance + 1)
        ):
            return candidate
    assert(false, "Expected samples immediately around the authored critical threshold.")
    return 0


func _verify_inherited_requirement(tip: BattleSkillActionNode) -> void:
    var root := BattleSkillActionNode.new()
    root.id = &"straight_punch_fixture"
    root.action = load(PUNCH_PATH) as ActionTemplate
    var ledger := BattleSkillInvestment.new()
    ledger._ranks = {root.id: 1, tip.id: 1}
    var errors := PackedStringArray()
    var components: Array[BattleSkillNode] = [root, tip]
    var compiled := tip._compile_action(&"uppercut_composite_fixture", components, ledger, errors)
    assert(errors.is_empty() and compiled != null)
    assert(compiled.equipment_requirements == root.action.equipment_requirements)
    assert(not compiled.equipment_requirements.is_empty())
    var f := _fixture(1)
    assert(f.actor.grant_action_from_source(&"uppercut_composite_fixture", compiled, 1))
    assert(f.actor.can_use_action(compiled))
    var hand: UnitEquipmentSlot
    for child in f.actor.get_children():
        if child is UnitEquipmentSlot and child.slot == UnitEquipmentSlot.SLOT.RightHand:
            hand = child
    assert(hand != null)
    var weapon := EquipmentWeaponTemplate.new()
    weapon.id = &"uppercut_test_weapon"
    weapon.equips_to = [UnitEquipmentSlot.SLOT.RightHand]
    await hand.equip(f.actor, weapon)
    assert(not f.actor.can_use_action(compiled))
    await hand.unequip()
    assert(f.actor.can_use_action(compiled))
    await _free_fixture(f)
