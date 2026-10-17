# Editor configuration for BattleSkillTreeCollection.
@tool
extends Resource
## At least one tree is required. Validation precedes runtime investment setup.
## Empty trees are permitted for units without purchasable skills.
class_name BattleSkillTreeCollection

## Unit-wide set of trees sharing one investment pool and node-ID namespace.
@export var trees: Array[BattleSkillTree] = []
## Optional initial investments. Applied once at unit initialization, never on restore or reset.
@export var default_assignment: BattleSkillDefaultAssignment


## Returns all authoring errors without modifying resources or addon state.
func validate() -> PackedStringArray:
    var errors := PackedStringArray()
    var tree_ids: Dictionary = {}
    var nodes: Dictionary = {}
    var owners: Dictionary = {}
    var node_columns: Dictionary = {}
    if trees.is_empty():
        errors.append("A skill collection requires at least one tree.")
    for tree in trees:
        if not tree or tree.id.is_empty() or tree_ids.has(tree.id):
            errors.append("Skill trees require unique nonempty IDs and non-null definitions.")
            continue
        tree_ids[tree.id] = true
        var columns: Dictionary = {}
        var cells: Dictionary = {}
        for tier in tree.tiers:
            if not tier or tier.column < 0 or columns.has(tier.column):
                errors.append("Tree %s has an invalid or duplicate tier column." % tree.id)
                continue
            columns[tier.column] = true
            _validate_bounds(tier.minimum_stats, tier.maximum_stats, errors)
            for node in tier.nodes:
                if not node or node.id.is_empty() or nodes.has(node.id):
                    errors.append("Skill nodes require unique collection-wide IDs and non-null definitions.")
                    continue
                nodes[node.id] = node
                owners[node.id] = tree.id
                node_columns[node.id] = tier.column
                var cell := Vector2i(tier.column, node.row)
                if node.row < 0 or cells.has(cell):
                    errors.append("Node %s has an invalid row or occupied cell." % node.id)
                cells[cell] = true
                if node.maximum_rank < 1 or node.maximum_rank > 99:
                    errors.append("Node %s has an invalid maximum rank." % node.id)
                _validate_bounds(node.minimum_stats, node.maximum_stats, errors)
                if node.composite and node.previous_node.is_empty():
                    errors.append("Composite node %s requires a predecessor." % node.id)
    for node: BattleSkillNode in nodes.values():
        for rank in node.prerequisites.values():
            if rank < 1:
                errors.append("Node %s has a non-positive prerequisite rank." % node.id)
        for key in dependencies(node):
            var rank: int = dependencies(node)[key]
            var prerequisite: BattleSkillNode = nodes.get(key)
            if not prerequisite or rank < 1 or rank > prerequisite.maximum_rank:
                errors.append("Node %s has a missing prerequisite or invalid prerequisite rank." % node.id)
        if not node.previous_node.is_empty():
            var previous: BattleSkillNode = nodes.get(node.previous_node)
            if (
                not previous
                or owners.get(previous.id) != owners[node.id]
                or previous.row != node.row
                or node_columns[previous.id] >= node_columns[node.id]
                or not node.accepts_predecessor(previous)
            ):
                errors.append("Node %s predecessor must be an earlier same-tree/row/kind node." % node.id)
    # Kahn traversal rejects cycles even across rows or trees.
    var remaining := nodes.duplicate()
    var completed: Dictionary = {}
    while not remaining.is_empty():
        var progressed := false
        for key in remaining.keys():
            var ready := true
            for dependency in dependencies(remaining[key]):
                if not completed.has(dependency):
                    ready = false
            if ready:
                completed[key] = true
                remaining.erase(key)
                progressed = true
        if not progressed:
            errors.append("Skill prerequisites contain a cycle or missing node.")
            break
    if default_assignment:
        errors.append_array(default_assignment.validate(nodes))
    return errors


## Returns a copy of explicit prerequisite ranks, adding at least rank one for previous_node
## without changing authored data.
static func dependencies(node: BattleSkillNode) -> Dictionary:
    var result: Dictionary = node.prerequisites.duplicate()
    if not node.previous_node.is_empty():
        result[node.previous_node] = maxi(1, int(result.get(node.previous_node, 0)))
    return result


## Appends errors for unknown stat IDs, nonfinite bounds or a minimum above its corresponding
## maximum.
static func _validate_bounds(minimum: Dictionary, maximum: Dictionary, errors: PackedStringArray) -> void:
    for bounds in [minimum, maximum]:
        for stat in bounds:
            if stat == CombatStats.STATS.Empty or stat not in CombatStats.STATS.values() or not is_finite(bounds[stat]):
                errors.append("Skill stat requirements need a known stat and finite bounds.")
    for stat in minimum:
        if maximum.has(stat) and minimum[stat] > maximum[stat]:
            errors.append("Skill stat requirement minimum exceeds its maximum.")


## Called once per runtime unit initialization, never by validation or UI redraws.
func warn_empty_tiers() -> void:
    var identity := resource_path if not resource_path.is_empty() else "runtime collection %s" % get_instance_id()
    for tree in trees:
        for tier in tree.tiers:
            if tier.nodes.is_empty():
                CustomLogger.warn(
                    self,
                    warn_empty_tiers,
                    (
                        "SkillTreeCollection %s: tree %s tier %s is empty and omitted at runtime."
                        % [identity, tree.id, tier.column]
                    ),
                    CustomLogger.LEVEL.IMPORTANT
                )
