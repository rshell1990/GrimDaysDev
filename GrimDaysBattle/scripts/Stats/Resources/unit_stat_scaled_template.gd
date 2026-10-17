# Editor configuration for UnitScaleddStatTemplate.
@tool
extends UnitStatTemplate
## Coordinates unit scaledd stat template behavior for the battle system.
class_name UnitScaleddStatTemplate

## Configures the influenced by used by this unit scaledd stat template.
@export var influenced_by: CombatStats.STATS
## Configures the to stat maximum curve used by this unit scaledd stat template.
@export var to_stat_maximum_curve: Curve
## Maximum contribution from the influencing attribute, NOT a final effective
## stat ceiling. Direct equipment/passive/effect modifiers apply after this cap.
@export var maximum: float
## Configures the minimum used by this unit scaledd stat template.
@export var minimum: float
