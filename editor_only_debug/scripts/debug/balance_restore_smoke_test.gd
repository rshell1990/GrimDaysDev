extends Node
## Isolated balance migration coverage using private definitions and in-memory JSON saves.

const CELINE = preload("res://GrimDaysBattle/resources/units/celine_teen/celine_battle_unit_template.tres")
const SIGNATURE = preload("res://GrimDaysBattle/scripts/Skills/Runtime/skill_definition_signature.gd")


class TestParty:
    extends BattlePartyManager

    func _ready() -> void:
        pass


func _ready() -> void:
    var passed := await _test_restore()
    if passed:
        print("BALANCE_RESTORE_SMOKE_TEST: PASS") # lint:ignore debug-print -- Required test/CLI output.
    get_tree().quit(0 if passed else 1)


func _template() -> BattleUnitTemplate:
    var template := CELINE.duplicate() as BattleUnitTemplate
    template.level = 3
    template.stats = CELINE.stats.duplicate()
    template.stats.all = []
    for stat in CELINE.stats.all:
        template.stats.all.append(stat.duplicate(true))
    template.starting_attribute_points_spent = {}
    template.leveling_tiers = CELINE.leveling_tiers.duplicate()
    template.leveling_tiers.all = []
    var tier = CELINE.leveling_tiers.all[0].duplicate()
    tier.combat_base_grant = 4
    tier.combat_per_level = 0
    tier.non_combat_base_grant = 2
    tier.non_combat_per_level = 0
    tier.skill_points_base_grant = 6
    tier.skill_points_per_level = 0
    template.leveling_tiers.all.append(tier)
    template.skill_collection = _skills()
    return template


func _skills() -> BattleSkillTreeCollection:
    var collection := BattleSkillTreeCollection.new()
    var tree := BattleSkillTree.new()
    tree.id = &"balance_test"
    var tier := BattleSkillTier.new()
    for row in 2:
        var node := BattleSkillPassiveNode.new()
        node.id = &"first" if row == 0 else &"second"
        node.row = row
        node.maximum_rank = 3
        var modifier := BattleSkillTreeStatGrant.new()
        modifier.modifier_id = &"bonus"
        modifier.stat = CombatStats.STATS.Strength if row == 0 else CombatStats.STATS.Vitality
        modifier.amounts_by_rank = PackedFloat32Array([1, 2, 3])
        node.passive_stat_modifiers = [modifier]
        if row == 1:
            node.prerequisites[&"first"] = 1
        tier.nodes.append(node)
    tree.tiers = [tier]
    collection.trees = [tree]
    return collection


func _spawn(template: BattleUnitTemplate) -> BattleUnit:
    var unit := BattleUnit.create(template, false)
    add_child(unit)
    return unit


func _stat_template(template: BattleUnitTemplate, stat_id: int) -> UnitStatTemplate:
    for stat in template.stats.all:
        if stat.type == stat_id:
            return stat
    return null


func _test_restore() -> bool:
    var party := TestParty.new()
    add_child(party)
    var old_template := _template()
    var old_unit := _spawn(old_template)
    var points := BattleAttributeProgression.snapshot(old_unit)
    assert(
        BattleAttributeProgression.spend(
            old_unit,
            {CombatStats.STATS.Strength: 3, CombatStats.STATS.Vitality: 1, CombatStats.STATS.Charisma: 1},
            points.revision
        )
    )
    assert(old_unit.skills.purchase({&"first": 2, &"second": 1}, old_unit.skills.revision).is_empty())
    var strength := old_unit.get_stat(CombatStats.STATS.Strength)
    strength.set_base(strength.Base + 2.0)  # Explicit persistent change, independent of spent points.
    old_unit.get_stat(CombatStats.STATS.Sanity).set_base(37.0)
    old_unit.get_stat(CombatStats.STATS.Willpower).add_modifier(
        UnitStatModifier.create(
            &"story_reward",
            &"story",
            CombatStats.STATS.Willpower,
            UnitStatModifier.OPERATION.FLAT_ADD,
            3.0,
            UnitStatModifier.LIFETIME.PERSISTENT
        )
    )
    for stat_type in BattlePartyManager.RESOURCE_STATS:
        old_unit.get_stat(stat_type).restore_current(0.25)
    var saved: Dictionary = JSON.parse_string(JSON.stringify(party._serialize_unit(old_unit)))
    var saved_copy := saved.duplicate(true)
    var unchanged := _spawn(old_template)
    party._restore_unit(unchanged, saved)
    for stat_type in BattlePartyManager.RESOURCE_STATS:
        assert(unchanged.get_stat(stat_type).Current == 0.25, "Ordinary loads preserve depleted pools.")
    var latest := _template()
    var latest_strength := _stat_template(latest, CombatStats.STATS.Strength)
    latest_strength.starting_amount += 5.0
    var restored := _spawn(latest)
    party._restore_unit(restored, saved)
    assert(restored.get_stat(CombatStats.STATS.Strength).Base == latest_strength.starting_amount + 2.0)
    assert(restored.attribute_progression.allocated == {"Strength": 3, "Vitality": 1, "Charisma": 1})
    assert(restored.skills.ledger.get_rank(&"first") == 2 and restored.skills.ledger.get_rank(&"second") == 1)
    assert(restored.get_stat(CombatStats.STATS.Experience).Base == old_unit.get_stat(CombatStats.STATS.Experience).Base)
    assert(restored.get_stat(CombatStats.STATS.Sanity).Base == 37.0)
    assert(restored.get_stat(CombatStats.STATS.Willpower).mods.has(&"story_reward"))
    for stat_type in BattlePartyManager.RESOURCE_STATS:
        var pool := restored.get_stat(stat_type)
        assert(pool.Current == pool.Max, "Baseline repair refills every pool after grants are rebuilt.")
    assert(saved == saved_copy, "Loading must not mutate the source save.")
    # Roundtrip rebased values without adding the baseline change a second time.
    for stat_type in BattlePartyManager.RESOURCE_STATS:
        restored.get_stat(stat_type).restore_current(0.75)
    var again: Dictionary = JSON.parse_string(JSON.stringify(party._serialize_unit(restored)))
    var repeated := _spawn(latest)
    party._restore_unit(repeated, again)
    assert(
        repeated.get_stat(CombatStats.STATS.Strength).Current == restored.get_stat(CombatStats.STATS.Strength).Current
    )
    for stat_type in BattlePartyManager.RESOURCE_STATS:
        assert(repeated.get_stat(stat_type).Current == 0.75, "A repaired save must not refill again.")
    # Legacy baseline cannot distinguish former defaults: current definitions win.
    var legacy := saved.duplicate(true)
    for stat in legacy.stats.values():
        stat.erase("template_base")
    legacy.skill_investment.erase("definition_signature")
    var migrated := _spawn(latest)
    party._restore_unit(migrated, legacy)
    assert(migrated.get_stat(CombatStats.STATS.Strength).Base == latest_strength.starting_amount)
    assert(migrated.attribute_progression.allocated == restored.attribute_progression.allocated)
    assert(migrated.skills.ledger.spent_points() == 0 and migrated.skills.snapshot().available == 6)
    for stat_type in BattlePartyManager.RESOURCE_STATS:
        assert(migrated.get_stat(stat_type).Current == migrated.get_stat(stat_type).Max)
    # Any attribute overspend resets BOTH pools, independent of dictionary insertion order.
    var reduced := _template()
    reduced.leveling_tiers.all[0].combat_base_grant = 2
    var refunded := _spawn(reduced)
    party._restore_unit(refunded, saved)
    assert(refunded.attribute_progression.allocated.is_empty())
    assert(BattleAttributeProgression.snapshot(refunded).available.combat == 2)
    assert(BattleAttributeProgression.snapshot(refunded).available.non_combat == 2)
    assert(refunded.skills.ledger.spent_points() == 3, "Unchanged skills stay purchased after attribute refunds.")
    # Current template starting distribution reduces the discretionary budget too.
    var redistributed := _template()
    redistributed.starting_attribute_points_spent = {"combat": 1}
    var redistributed_unit := _spawn(redistributed)
    party._restore_unit(redistributed_unit, saved)
    assert(redistributed_unit.attribute_progression.allocated.is_empty())
    # Skill budget reduction resets the entire ledger; no automatic rank trimming.
    var skill_budget := _template()
    skill_budget.leveling_tiers.all[0].skill_points_base_grant = 2
    var skill_refund := _spawn(skill_budget)
    party._restore_unit(skill_refund, saved)
    assert(skill_refund.skills.ledger.spent_points() == 0 and skill_refund.skills.snapshot().available == 2)
    # Gameplay changes reset even when every old rank remains structurally legal.
    var changed := _template()
    changed.skill_collection.trees[0].tiers[0].nodes[0].passive_stat_modifiers[0].amounts_by_rank[0] = 1.5
    var changed_unit := _spawn(changed)
    party._restore_unit(changed_unit, saved)
    assert(changed_unit.skills.ledger.spent_points() == 0)
    assert(changed_unit.attribute_progression.allocated == restored.attribute_progression.allocated)
    assert(
        not changed_unit.get_stat(CombatStats.STATS.Strength).mods.keys().any(
            func(key): return String(key).begins_with("project_skill:")
        )
    )
    # Presentation edits and fresh resource instances do not invalidate purchases.
    var cosmetic := _template()
    cosmetic.skill_collection.trees[0].tiers[0].nodes[0].description = "New wording"
    cosmetic.skill_collection.trees[0].tiers[0].nodes[0].row = 5
    assert(SIGNATURE.for_collection(cosmetic.skill_collection) == saved.skill_investment.definition_signature)
    # Prerequisite and rank-limit changes do invalidate the gameplay signature.
    cosmetic.skill_collection.trees[0].tiers[0].nodes[1].prerequisites[&"first"] = 2
    assert(SIGNATURE.for_collection(cosmetic.skill_collection) != saved.skill_investment.definition_signature)
    var post_reset := party._serialize_unit(changed_unit)
    var reset_again := _spawn(changed)
    party._restore_unit(reset_again, post_reset)
    assert(reset_again.skills.ledger.spent_points() == 0 and reset_again.skills.snapshot().available == 6)
    # A runtime gate lock is not an authored tree change and must not refund a build.
    var gated := _template()
    gated.skill_collection.trees[0].tiers[0].nodes[0].maximum_stats[CombatStats.STATS.Sanity] = 50
    var gated_unit := _spawn(gated)
    gated_unit.get_stat(CombatStats.STATS.Sanity).set_base(37)
    assert(gated_unit.skills.purchase({&"first": 1}, gated_unit.skills.revision).is_empty())
    var gate_save := party._serialize_unit(gated_unit)
    gate_save.stats.Sanity.base = 90
    var locked_unit := _spawn(gated)
    party._restore_unit(locked_unit, gate_save)
    assert(locked_unit.skills.ledger.get_rank(&"first") == 1)
    assert(not locked_unit.skills.ledger.is_available(&"first", locked_unit.skills.stat_values()))
    # Removed nodes and lower rank caps refund every tree investment, not just the affected node.
    var removed := _template()
    removed.skill_collection.trees[0].tiers[0].nodes.remove_at(1)
    var removed_unit := _spawn(removed)
    party._restore_unit(removed_unit, saved)
    assert(removed_unit.skills.ledger.spent_points() == 0)
    var capped := _template()
    capped.skill_collection.trees[0].tiers[0].nodes[0].maximum_rank = 1
    var capped_unit := _spawn(capped)
    party._restore_unit(capped_unit, saved)
    assert(capped_unit.skills.ledger.spent_points() == 0)
    # Malformed allocations reset as a whole; no partial build depends on key order.
    var malformed := saved.duplicate(true)
    malformed.attribute_progression.allocated = {"Strength": 1, "Vitality": 1.5, "Charisma": 1}
    var malformed_unit := _spawn(latest)
    party._restore_unit(malformed_unit, malformed)
    assert(malformed_unit.attribute_progression.allocated.is_empty())
    # Refunded points can be reassigned by normal purchase APIs, without inflated earnings.
    var refund_points := BattleAttributeProgression.snapshot(refunded)
    assert(BattleAttributeProgression.spend(refunded, {CombatStats.STATS.Finesse: 2}, refund_points.revision))
    assert(changed_unit.skills.purchase({&"first": 1}, changed_unit.skills.revision).is_empty())
    assert(changed_unit.skills.snapshot().available == 5)
    var reassigned := _spawn(changed)
    party._restore_unit(reassigned, party._serialize_unit(changed_unit))
    assert(reassigned.skills.ledger.get_rank(&"first") == 1)
    for child in get_children():
        child.queue_free()
    await get_tree().process_frame
    return true
