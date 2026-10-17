#region RANK
extends ResourceTemplate
##
##
##
## Coordinates rank template behavior for the battle system.
class_name RankTemplate
#endregion

#region VARIABLES
## Configures the level used by this rank template.
@export var level: int
## Configures the cost used by this rank template.
@export var cost: Dictionary[CombatStats.STATS, int]
## Number of the owning unit's future turns during which this action is unavailable.
@export_range(0, 99, 1) var cooldown_turns: int
## Configures the effects used by this rank template.
@export var effects: EffectTemplates
#endregion
