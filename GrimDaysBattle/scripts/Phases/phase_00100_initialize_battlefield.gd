extends BattlePhase
## Battle phase responsible for initialize battlefield.
class_name BattlePhaseInitializeBattlefield


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    super()


## Validates and prepares transient state when the phase becomes active.
func _enter() -> void:
    super()
    assert(cargo.has("allies") and cargo.has("foes"))
    entered.emit()


## Executes the initialize battlefield step and advances the phase state machine when complete.
func execute() -> void:
    super()
    BattleController.init_battlefield(cargo.allies, cargo.foes)
    executed.emit()
    BattleController.go_to_next_phase()


## Publishes the phase result and clears transient state before advancing.
func _exit() -> void:
    super()
    exited.emit()
