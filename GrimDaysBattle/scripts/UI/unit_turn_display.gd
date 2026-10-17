extends Panel
## Controls the unit turn displayer presentation used by the battle interface.
class_name UnitTurnDisplayer
## Fixed max size value shared by all unit turn displayer instances.
const MAX_SIZE: Vector2 = Vector2(128, 128)
## Fixed portrait size value shared by all unit turn displayer instances.
const PORTRAIT_SIZE: Vector2 = Vector2(128, 128)
## Configures the portrait holder used by this unit turn displayer.
@export var portrait_holder: TextureRect


## Initializes this unit turn displayer from the supplied runtime dependencies.
func setup(template: BattleUnitTemplate) -> void:
    portrait_holder.texture = template.portrait
    name = template.id
