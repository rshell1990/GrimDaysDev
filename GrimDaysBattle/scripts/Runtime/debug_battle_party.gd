# Editor configuration for UnitPartyDebug.
@icon("res://GrimDays/assets/visuals/class_icons/dark-squad.svg")
extends Node
## Coordinates unit party debug behavior for the battle system.
class_name UnitPartyDebug

## Emitted when all defeated.
signal all_defeated


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    var BattleController = get_parent()
    var components = BattleController.get_children()


## Adds to party for this unit party debug.
func add_to_party(template: BattleUnitTemplate) -> void:
    var new_unit = BattleUnit.create(template)
    add_child(new_unit)
