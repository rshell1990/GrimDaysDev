extends BattlePhase
## Battle phase responsible for initialize turn order.
class_name BattlePhaseInitializeTurnOrder

## Ordered runtime collection of all units.
var all_units: Array = []


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    super()


## Validates and prepares transient state when the phase becomes active.
func _enter() -> void:
    super()
    all_units.clear()
    all_units.assign(BattleController.get_all_active_units())

    all_units.sort_custom(sort_by_speed)

    entered.emit()


## Sorts by speed for this phase initialize turn order.
func sort_by_speed(first_unit, second_unit) -> bool:
    if first_unit.speed > second_unit.speed:
        return true
    return false


## Executes the initialize turn order step and advances the phase state machine when complete.
func execute() -> void:
    super()
    BattleController.turn_controller.turn_order = all_units
    SignalBus.init_turn_order.emit(all_units)
    executed.emit()
    BattleController.go_to_next_phase()


## Publishes the phase result and clears transient state before advancing.
func _exit() -> void:
    super()

    exited.emit()
