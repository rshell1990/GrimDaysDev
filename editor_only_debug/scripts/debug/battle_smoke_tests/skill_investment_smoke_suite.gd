extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"
## Project-owned purchases/availability; no addon, UI or player save files.


func run() -> void:
    _test_investment()
    _test_validation()


## Authors tier-owned nodes for a four-column chain, an AND-prerequisite branch and a separate
## passive tree sharing one point pool.
func _definitions() -> BattleSkillTreeCollection:
    var collection := BattleSkillTreeCollection.new()
    var tree := BattleSkillTree.new()
    tree.id = &"martial"
    for column in range(4):
        var tier := BattleSkillTier.new()
        tier.column = column
        tier.minimum_stats[CombatStats.STATS.Level] = column + 1
        if column == 2:
            tier.maximum_stats[CombatStats.STATS.Sanity] = 50
        tree.tiers.append(tier)
        var node := BattleSkillActionNode.new()
        node.id = StringName(["a", "b", "c", "d"][column])
        node.maximum_rank = 3 if column == 0 else 1
        if column > 0:
            node.previous_node = tree.tiers[column - 1].nodes[0].id
            node.composite = column != 2
        tree.tiers[column].nodes.append(node)
    tree.tiers[1].nodes[0].prerequisites[&"a"] = 2
    var branch := BattleSkillActionNode.new()
    branch.id = &"branch"
    branch.row = 1
    branch.prerequisites = {&"a": 2, &"b": 1}
    branch.minimum_stats[CombatStats.STATS.Strength] = 10
    tree.tiers[0].nodes.append(branch)
    var second := BattleSkillTree.new()
    second.id = &"defense"
    second.tiers = [BattleSkillTier.new()]
    var passive := BattleSkillPassiveNode.new()
    passive.id = &"passive"
    passive.maximum_rank = 2
    second.tiers[0].nodes = [passive]
    collection.trees = [tree, second]
    return collection


## Checks atomic purchases, revisions, unit isolation, gate changes, JSON restoration and full
## reset without altering authored resources.
func _test_investment() -> void:
    var definitions := _definitions()
    assert(definitions.validate().is_empty())
    var ledger := BattleSkillInvestment.new()
    assert(ledger.configure(definitions).is_empty())
    var other_unit := BattleSkillInvestment.new()
    assert(other_unit.configure(definitions).is_empty())
    var values := {CombatStats.STATS.Level: 4, CombatStats.STATS.Sanity: 30, CombatStats.STATS.Strength: 10}
    var version := ledger.revision
    assert(not ledger.purchase({&"b": 1}, 8, values, version).is_empty())
    assert(ledger.revision == version and ledger.spent_points() == 0)
    # Later nodes may precede prerequisites in a draft: validate the whole transaction.
    assert(ledger.purchase({&"d": 1, &"c": 1, &"b": 1, &"a": 2, &"branch": 1}, 8, values, version).is_empty())
    assert(ledger.spent_points() == 6 and ledger.available_points(8) == 2)
    assert(other_unit.spent_points() == 0)
    assert(not ledger.purchase({&"passive": 1}, 8, values, version).is_empty())
    assert(ledger.purchase({&"passive": 2}, 8, values, ledger.revision).is_empty())
    assert(ledger.available_points(8) == 0, "One pool spans both trees.")
    var baseline := ledger.capture()
    assert(not ledger.purchase({&"a": 1}, 8, values, ledger.revision).is_empty())
    for invalid in [{&"passive": 1}, {&"a": -1}, {&"a": 0.5}, {&"a": true}, {&"a": 1, &"missing": 1}]:
        assert(not ledger.purchase(invalid, 100, values, ledger.revision).is_empty())
        assert(ledger.capture() == baseline)
    assert(ledger.is_available(&"d", values))
    values[CombatStats.STATS.Sanity] = 70
    assert(not ledger.is_available(&"c", values) and not ledger.is_available(&"d", values))
    assert(ledger.is_available(&"b", values) and ledger.get_rank(&"d") == 1)
    assert(ledger.capture() == baseline, "Availability never erases purchases.")
    values[CombatStats.STATS.Sanity] = 50
    assert(ledger.is_available(&"d", values), "Inclusive bounds restore availability.")
    values[CombatStats.STATS.Level] = 1
    assert(not ledger.is_available(&"branch", values))
    values[CombatStats.STATS.Level] = 4
    values.erase(CombatStats.STATS.Strength)
    assert(not ledger.is_available(&"branch", values))
    values[CombatStats.STATS.Strength] = NAN
    assert(not ledger.is_available(&"branch", values))
    var restored := BattleSkillInvestment.new()
    assert(restored.configure(definitions).is_empty())
    assert(restored.restore(JSON.parse_string(JSON.stringify(baseline)), 8).is_empty())
    assert(restored.capture() == baseline)
    for invalid in [
        {},
        {"version": 2, "ranks": {}},
        {"version": true, "ranks": {}},
        {"version": 1, "ranks": {"unknown": 1}},
        {"version": 1, "ranks": {"b": 1}},
        {"version": 1, "ranks": {"a": 4}},
        {"version": 1, "ranks": {"a": 1.5}},
        {"version": 1, "ranks": {"a": INF}},
        {"version": 1, "ranks": {"a": true}}
    ]:
        assert(not restored.restore(invalid, 8).is_empty())
        assert(restored.capture() == baseline)
    assert(not restored.restore(baseline, 7).is_empty())
    version = restored.revision
    assert(restored.reset_all(version) == 8 and restored.available_points(8) == 8)
    assert(restored.reset_all(version) == -1)
    assert(ledger.capture() == baseline and definitions.trees[0].tiers[0].nodes[0].maximum_rank == 3)
    assert(
        not (
            other_unit
            . purchase(
                {&"a": 2, &"b": 1, &"branch": 1},
                8,
                {CombatStats.STATS.Level: 4, CombatStats.STATS.Strength: 9},
                other_unit.revision
            )
            . is_empty()
        )
    )
    assert(other_unit.spent_points() == 0, "A failed additional requirement rejects the whole draft.")
    assert(not other_unit.configure(BattleSkillTreeCollection.new()).is_empty())
    assert(other_unit.purchase({&"a": 1}, 8, {CombatStats.STATS.Level: 1}, other_unit.revision).is_empty())


## Checks empty trees, reordered tiers and independent flattened views; omits empty tiers and rejects
## duplicate/null nodes, occupied cells and invalid prerequisites or bounds.
func _test_validation() -> void:
    assert(not BattleSkillTreeCollection.new().validate().is_empty())
    var empty_tree := BattleSkillTree.new()
    empty_tree.id = &"empty"
    var empty_collection := BattleSkillTreeCollection.new()
    empty_collection.trees = [empty_tree]
    assert(empty_collection.validate().is_empty())
    var reordered := _definitions()
    reordered.trees[0].tiers.reverse()
    var ledger := BattleSkillInvestment.new()
    assert(ledger.configure(reordered).is_empty())
    assert(ledger.get_column(&"a") == 0 and ledger.get_column(&"d") == 3)
    var flattened := reordered.trees[0].get_nodes()
    flattened.clear()
    assert(reordered.trees[0].get_nodes().size() == 5)
    var mutations: Array[Callable] = [
        func(c): c.trees[1].tiers[0].nodes[0].id = &"a",
        func(c): c.trees[0].tiers[0].nodes[0].prerequisites[&"b"] = 1,
        func(c): c.trees[0].tiers[1].nodes[0].row = 2,
        func(c): c.trees[0].tiers[1].nodes[0].previous_node = &"passive",
        func(c): c.trees[0].tiers[1].nodes[0].prerequisites[&"missing"] = 1,
        func(c): c.trees[0].tiers[1].nodes[0].prerequisites[&"a"] = 4,
        func(c): c.trees[0].tiers[1].nodes[0].prerequisites[&"a"] = 0,
        func(c): c.trees[0].tiers[1].column = 0,
        func(c): c.trees[0].tiers[0].minimum_stats[CombatStats.STATS.Level] = NAN,
        func(c): c.trees[0].tiers[0].maximum_stats[CombatStats.STATS.Level] = -1,
        func(c): c.trees[0].tiers.append(BattleSkillTier.new()),
        func(c): c.trees[0].tiers[0].nodes.append(null),
        func(c): c.trees[0].tiers[1].nodes.append(c.trees[0].tiers[0].nodes[0]),
        func(c): c.trees[0].tiers[0].nodes[1].row = 0,
    ]
    for mutate in mutations:
        var definitions := _definitions()
        mutate.call(definitions)
        assert(not definitions.validate().is_empty())

    var placeholders := _definitions()
    var tree: BattleSkillTree = placeholders.trees[1]
    var tier: BattleSkillTier = tree.tiers[0]
    tier.nodes.clear()
    assert(placeholders.validate().is_empty())
    assert(tree.get_runtime_tiers().is_empty())
    assert(tree.tiers == [tier], "Runtime omission must not rewrite authored resources.")
