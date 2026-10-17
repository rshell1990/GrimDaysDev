extends BattlePhase
## Battle phase responsible for process target kill.
class_name BattlePhaseProcessTargetKill


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    super()


## Validates and prepares transient state when the phase becomes active.
func _enter() -> void:
    super()
    entered.emit()


## Executes the process target kill step and advances the phase state machine when complete.
func execute() -> void:
    super()
    executed.emit()


## Publishes the phase result and clears transient state before advancing.
func _exit() -> void:
    super()
    exited.emit()
