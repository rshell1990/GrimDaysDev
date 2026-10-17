# Editor configuration for BattleSkillTreeStatGrant.
@tool
extends Resource
## Coordinates battle skill tree stat grant behavior for the battle system.
class_name BattleSkillTreeStatGrant

## Stable identity within its owning project skill passive node.
@export var modifier_id: StringName
## Configures the stat used by this skill tree stat grant.
@export var stat: CombatStats.STATS = CombatStats.STATS.Empty
## Configures the operation used by this skill tree stat grant.
@export var operation: UnitStatModifier.OPERATION = UnitStatModifier.OPERATION.FLAT_ADD
## One value per purchased rank, starting at rank one; no addon runtime dependency.
@export var amounts_by_rank: PackedFloat32Array
## Configures the priority used by this skill tree stat grant.
@export var priority: int


## Returns amount for this skill tree stat grant.
func get_amount(allocation_rank: int) -> float:
    if allocation_rank < 1 or amounts_by_rank.is_empty():
        return 0.0
    return amounts_by_rank[mini(allocation_rank, amounts_by_rank.size()) - 1]
