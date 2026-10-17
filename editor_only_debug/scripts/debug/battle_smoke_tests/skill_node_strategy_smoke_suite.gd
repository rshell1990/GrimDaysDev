## Tool mode matches the tool-enabled resource used by the nested probe.
@tool
extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/skill_chain_smoke_suite.gd"
## Strategy dispatch, exclusive Inspector payloads and resource/save compatibility.


class ProbeAction:
    extends BattleSkillActionNode
    var validation_called: bool = false
    var compilation_called: bool = false

    func validate_payload(_errors: PackedStringArray) -> void:
        validation_called = true

    func append_chain_plan(
        _source: StringName,
        _components: Array[BattleSkillNode],
        _ledger: BattleSkillInvestment,
        _signature: Array,
        _result: Dictionary
    ) -> void:
        compilation_called = true


func run() -> void:
    _test_strategy_dispatch()
    _test_payload_properties()
    _test_mixed_chain_rejected()
    _test_resource_roundtrip()


func _test_strategy_dispatch() -> void:
    var node := ProbeAction.new()
    node.id = &"probe"
    var tier := BattleSkillTier.new()
    tier.nodes = [node]
    var tree := BattleSkillTree.new()
    tree.id = &"probe_tree"
    tree.tiers = [tier]
    var collection := BattleSkillTreeCollection.new()
    collection.trees = [tree]
    var ledger := BattleSkillInvestment.new()
    assert(ledger.configure(collection).is_empty())
    assert(ledger.purchase({&"probe": 1}, 1, {}, ledger.revision).is_empty())
    assert(BattleSkillChainResolver.resolve(ledger, {}).errors.is_empty())
    assert(node.validation_called and node.compilation_called)


func _test_payload_properties() -> void:
    var action := BattleSkillActionNode.new()
    var passive := BattleSkillPassiveNode.new()
    var action_properties := _property_names(action)
    var passive_properties := _property_names(passive)
    assert("action" in action_properties)
    assert("passive_stat_modifiers" not in action_properties)
    assert("passive_effects_by_rank" not in action_properties)
    assert("action" not in passive_properties)
    assert("passive_stat_modifiers" in passive_properties)
    assert("passive_effects_by_rank" in passive_properties)
    assert("kind" not in action_properties and "kind" not in passive_properties)
    assert(action.has_action_source() and not passive.has_action_source())
    assert(action.get_payload_label() == "Action" and passive.get_payload_label() == "Passive")
    assert(not BattleSkillPayloadValidator.validate([action, passive]).is_empty())


func _property_names(resource: Resource) -> PackedStringArray:
    var names := PackedStringArray()
    for property in resource.get_property_list():
        if property.usage & PROPERTY_USAGE_STORAGE:
            names.append(property.name)
    return names


func _test_mixed_chain_rejected() -> void:
    var fixture := _fixture()
    var previous: BattleSkillNode = fixture.collection.trees[0].tiers[0].nodes[0]
    var successor := BattleSkillPassiveNode.new()
    successor.id = &"mixed"
    successor.row = previous.row
    successor.previous_node = previous.id
    fixture.collection.trees[0].tiers[1].nodes[0] = successor
    assert(not successor.accepts_predecessor(previous))
    assert(not previous.accepts_predecessor(successor))
    assert(not fixture.collection.validate().is_empty())


func _test_resource_roundtrip() -> void:
    var fixture := _fixture()
    var path := "user://skill_node_strategy_%s.tres" % Time.get_ticks_usec()
    assert(ResourceSaver.save(fixture.collection, path) == OK)
    var restored: BattleSkillTreeCollection = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
    assert(restored and restored.validate().is_empty())
    assert(restored.trees[0].tiers[0].nodes[0] is BattleSkillActionNode)
    assert(restored.trees[0].tiers[0].nodes[1] is BattleSkillPassiveNode)
    var ledger := BattleSkillInvestment.new()
    assert(ledger.configure(restored).is_empty())
    assert(ledger.restore(fixture.ledger.capture(), 20).is_empty())
    var before := BattleSkillChainResolver.resolve(fixture.ledger, fixture.values)
    var after := BattleSkillChainResolver.resolve(ledger, fixture.values)
    assert(after.errors.is_empty())
    assert(before.actions.keys() == after.actions.keys())
    assert(before.passives.keys() == after.passives.keys())
    assert(ledger.capture() == fixture.ledger.capture())
    assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK)
    var control: BattleSkillPassiveNode = load( # lint:ignore load-in-var -- Load fixtures during test execution.
        "res://GrimDaysBattle/resources/skill_trees/celine/troubled_youth/tier 3/control_node.tres"
    )
    assert(control.id == &"control" and control.maximum_rank == 5)
    assert(BattleSkillPayloadValidator.validate([control]).is_empty())
