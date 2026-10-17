extends BattlePhase
## Battle phase responsible for victory.
class_name BattlePhaseVictory


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    super()


## Validates and prepares transient state when the phase becomes active.
func _enter() -> void:
    super()
    entered.emit()


## Executes the victory step and advances the phase state machine when complete.
func execute() -> void:
    super()
    BattleController.finish_battle(BattleResult.OUTCOME.VICTORY)
    executed.emit()


## Publishes the phase result and clears transient state before advancing.
func _exit() -> void:
    super()
    exited.emit()
