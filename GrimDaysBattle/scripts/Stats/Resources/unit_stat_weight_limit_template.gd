# Editor configuration for UnitWeightLimitTemplate.
@tool
extends UnitStatTemplate
## Coordinates unit weight limit template behavior for the battle system.
class_name UnitWeightLimitTemplate

## Configures the influenced by used by this unit weight limit template.
@export var influenced_by: Array[CombatStats.STATS]
## Per-point capacity gains, accumulated through the rounded average of dependencies.
@export var growth_curve: Curve
