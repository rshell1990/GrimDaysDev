extends RefCounted
## Pure derivation: purchases + current gates -> independent runtime action plans
## and passive component grants. Does not mutate units, resources or investment.
class_name BattleSkillChainResolver

## Namespace for generated chain action and passive source IDs.
const SOURCE_PREFIX := "project_skill:"


## Returns {errors, actions, passives}. No partial plans are returned on failure.
## One highest available tip per connected same-row chain is exposed. Cross-row
## prerequisites gate availability but never contribute effects or hide actions.
static func resolve(ledger: BattleSkillInvestment, stat_values: Dictionary) -> Dictionary:
    var result := {"errors": PackedStringArray(), "actions": {}, "passives": {}}
    if not ledger:
        result.errors.append("Missing skill investment ledger.")
        return result
    result.errors = ledger.validate_definitions()
    if not result.errors.is_empty():
        return result
    var nodes := ledger.get_nodes()
    result.errors = BattleSkillPayloadValidator.validate(nodes)
    if not result.errors.is_empty():
        return result
    var by_id: Dictionary = {}
    for node in nodes:
        by_id[node.id] = node
    var tips: Dictionary = {}
    for node in nodes:
        if not ledger.is_available(node.id, stat_values):
            continue
        var root := node
        while not root.previous_node.is_empty():
            root = by_id[root.previous_node]
        if not tips.has(root.id) or ledger.get_column(node.id) > ledger.get_column(tips[root.id].id):
            tips[root.id] = node
    # Deterministic order independent of dictionary insertion in restored data.
    var roots := tips.keys()
    roots.sort()
    for root_id in roots:
        var tip: BattleSkillNode = tips[root_id]
        var components := components_for(tip, by_id)
        var source := StringName(SOURCE_PREFIX + JSON.stringify([String(ledger.get_tree_id(tip.id)), String(root_id)]))
        var signature: Array = []
        for component in components:
            signature.append([component.id, ledger.get_rank(component.id)])
        tip.append_chain_plan(source, components, ledger, signature, result)
    if not result.errors.is_empty():
        result.actions.clear()
        result.passives.clear()
    return result


## Shared retention rule for active grants and selected-node accounting. Definitions are validated first.
static func components_for(tip: BattleSkillNode, by_id: Dictionary) -> Array[BattleSkillNode]:
    var components: Array[BattleSkillNode] = [tip]
    var cursor := tip
    while cursor.composite and not cursor.previous_node.is_empty():
        cursor = by_id[cursor.previous_node]
        components.push_front(cursor)
    return components


## Read-only accounting for a purchased node, even when gated or superseded by a later tip.
## This is not an active grant plan and must never be passed to reconciliation.
static func preview_node(node_id: StringName, ledger: BattleSkillInvestment) -> Dictionary:
    var result := {"errors": PackedStringArray(), "actions": {}, "passives": {}}
    result.errors = ledger.validate_definitions()
    if not result.errors.is_empty():
        return result
    var nodes := ledger.get_nodes()
    result.errors = BattleSkillPayloadValidator.validate(nodes)
    if not result.errors.is_empty():
        return result
    var by_id: Dictionary = {}
    for node in nodes:
        by_id[node.id] = node
    if not by_id.has(node_id) or ledger.get_rank(node_id) == 0:
        return result
    var node: BattleSkillNode = by_id[node_id]
    var components := components_for(node, by_id)
    for component in components:
        if ledger.get_rank(component.id) == 0:
            result.errors.append("Missing invested component: %s." % component.id)
            return result
    node.append_chain_plan(&"preview_only", components, ledger, [], result)
    return result
