# Initial investments for a newly created unit; saved ranks always take precedence.
@tool
extends Resource
class_name BattleSkillDefaultAssignment

## Absolute starting ranks, indexed by collection-wide node ID. Omit unpurchased nodes.
@export var ranks: Dictionary[StringName, int] = {}


## Structural validation is independent of a unit's earned points and current gates.
func validate(nodes: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    for id in ranks:
        var node: BattleSkillNode = nodes.get(id)
        if not node or ranks[id] < 1 or ranks[id] > node.maximum_rank:
            errors.append("Default skill assignment has an unknown node or invalid rank: %s." % id)
            continue
        for dependency in BattleSkillTreeCollection.dependencies(node):
            if ranks.get(dependency, 0) < BattleSkillTreeCollection.dependencies(node)[dependency]:
                errors.append("Default skill assignment is missing a prerequisite for %s." % id)
    return errors
