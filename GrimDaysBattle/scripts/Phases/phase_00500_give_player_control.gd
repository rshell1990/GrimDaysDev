extends BattlePhase
## Battle phase responsible for give player control.
class_name BattlePhaseGivePlayerControl


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    super()


## Validates and prepares transient state when the phase becomes active.
func _enter() -> void:
    super()
    SignalBus.battle_action_select.emit()
    entered.emit()


## Executes the give player control step and advances the phase state machine when complete.
func execute() -> void:
    super()
    executed.emit()
    BattleController.go_to_next_phase()


## Publishes the phase result and clears transient state before advancing.
func _exit() -> void:
    super()
    exited.emit()
