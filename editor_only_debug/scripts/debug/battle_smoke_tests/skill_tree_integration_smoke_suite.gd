extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"
## Real replacement resources through purchase, grants, persistence and retry.


class TestParty:
    extends BattlePartyManager

    func _ready() -> void:
        pass


func run() -> void:
    assert(not get_tree().root.has_node("YggdrasilLoader"))
    assert(not get_tree().root.has_node("YggdrasilSerializer"))
    assert(CELINE_TEMPLATE.skill_collection != null)
    var template := CELINE_TEMPLATE.duplicate() as BattleUnitTemplate
    template.level = 3
    var party := TestParty.new()
    add_child(party)
    var unit := BattleUnit.create(template)
    assert(unit)
    party.add_child(unit)
    assert(unit.skills)
    party.runtime_units[template.id] = unit
    party.active_party_ids.assign([template.id])
    assert(party.acquire_preparation(self))
    var authored_tree := template.skill_collection.trees[0]
    var authored_tiers := authored_tree.tiers.duplicate()
    var runtime_tiers := authored_tree.get_runtime_tiers()
    assert(not runtime_tiers.is_empty())
    # Exercise placeholder filtering independently of the production tree's current authoring stage.
    var placeholder_tree := authored_tree.duplicate(false) as BattleSkillTree
    placeholder_tree.tiers = authored_tiers.duplicate()
    placeholder_tree.tiers.append(BattleSkillTier.new())
    assert(placeholder_tree.get_runtime_tiers() == runtime_tiers)
    assert(placeholder_tree.tiers.size() == authored_tiers.size() + 1)
    var lucidity := unit.get_stat(CombatStats.STATS.Lucidity)
    var before := lucidity.Max
    assert(
        (
            party
            . purchase_skills(template.id, {&"straight_punch_node": 1, &"control": 1}, unit.skills.revision, self)
            . is_empty()
        )
    )
    assert(unit.skills.ledger.spent_points() == 2)
    assert(lucidity.Max > before, "Control must grant its authored passive immediately.")
    var plan := BattleSkillChainResolver.resolve(unit.skills.ledger, unit.skills.stat_values())
    assert(plan.errors.is_empty() and plan.actions.size() == 1 and plan.passives.size() == 1)
    var entry: Dictionary = plan.actions.values()[0]
    assert(unit.owns_action(entry.action) == false, "Only the published compiled snapshot is executable.")
    var action: ActionTemplate = unit._owned_actions[entry.action.id]
    assert(action.get_script() == preload("res://GrimDaysBattle/scripts/Actions/Resources/action.gd"))
    assert(unit.get_action_rank(action) == 1 and unit.can_use_action(action))
    unit._action_cooldowns[action.id] = 4
    lucidity.restore_current(lucidity.Max * 0.37)
    var saved := party._serialize_unit(unit)
    assert(saved.actions.action_grants.is_empty(), "Derived grants are rebuilt from investment.")
    assert(not saved.has("skill_trees"))
    var restored := BattleUnit.create(template)
    party.add_child(restored)
    assert(restored.skills.ledger.spent_points() == 0, "Instances must not share purchases.")
    party._restore_unit(restored, saved)
    assert(restored.skills.capture() == unit.skills.capture())
    assert(restored._owned_actions.has(action.id) and restored._action_cooldowns[action.id] == 4)
    assert(is_equal_approx(restored.get_stat(CombatStats.STATS.Lucidity).Max, lucidity.Max))
    assert(is_equal_approx(restored.get_stat(CombatStats.STATS.Lucidity).Current, lucidity.Current))
    var checkpoint := BattleRetryCheckpoint.new()
    checkpoint.capture([restored])
    restored.on_turn_started()
    assert(checkpoint.restore() and restored._action_cooldowns[action.id] == 4)
    assert(authored_tree.tiers == authored_tiers, "Runtime operations must preserve authored tiers.")
    party.release_preparation(self)
    await free_node(party)
