# Editor configuration for BattleSkillTree.
@tool
extends Resource
## A left-to-right tier/row grid; the runtime investment pool belongs to the unit.
class_name BattleSkillTree

## Stable tree identity, unique within a unit's collection.
@export var id: StringName
## Label shown on the preparation tree tab.
@export var display_name: String
## Owned grid columns and their node definitions; an empty tree has no purchasable skills.
@export var tiers: Array[BattleSkillTier] = []


## Flattened read view. Author nodes on their owning tier.
func get_nodes() -> Array[BattleSkillNode]:
    var result: Array[BattleSkillNode] = []
    for tier in tiers:
        if tier:
            result.append_array(tier.nodes)
    return result


## Runtime view omits placeholders without changing authored columns or resources.
func get_runtime_tiers() -> Array[BattleSkillTier]:
    var result: Array[BattleSkillTier] = []
    for tier in tiers:
        if tier and not tier.nodes.is_empty():
            result.append(tier)
    return result
