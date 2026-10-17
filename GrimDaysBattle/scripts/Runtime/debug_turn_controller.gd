# Editor configuration for DebugTurnController.
@icon("res://GrimDays/assets/visuals/class_icons/empty-hourglass.svg")
extends Node
## Coordinates debug turn controller behavior for the battle system.
class_name DebugTurnController

## Emitted to notify listeners that done upating occurred.
signal done_upating

## Ordered runtime collection of turn order.
var turn_order: Array
## Whether the updating condition currently holds.
var updating: bool


## Updates turn order on unit defeat for this debug turn controller.
func update_turn_order_on_unit_defeat(defeated: Array) -> Array[int]:
    updating = true
    var units_removed: Array[int] = []
    for x in range(turn_order.size() - 1, -1, -1):
        if turn_order[x] in defeated:
            turn_order.remove_at(x)
            units_removed.append(x)
    updating = false
    done_upating.emit()
    return units_removed


## Sets next unit for this debug turn controller.
func set_next_unit() -> void:
    if not turn_order.is_empty():
        turn_order.pop_front()
