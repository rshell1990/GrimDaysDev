extends BattlePhase
## Battle phase responsible for get action from player.
class_name BattlePhaseGetActionFromPlayer


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    super()


## Validates and prepares transient state when the phase becomes active.
func _enter() -> void:
    super()
    entered.emit()


## Executes the get action from player step and advances the phase state machine when complete.
func execute() -> void:
    await SignalBus.battle_action_selected
    super()
    executed.emit()
    BattleController.go_to_next_phase(cargo)


## Publishes the phase result and clears transient state before advancing.
func _exit() -> void:
    super()
    exited.emit()
