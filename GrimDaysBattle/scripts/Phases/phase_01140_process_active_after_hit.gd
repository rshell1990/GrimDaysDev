extends BattlePhase
## Battle phase responsible for process active after hit.
class_name BattlePhaseProcessActiveAfterHit


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    super()


## Validates and prepares transient state when the phase becomes active.
func _enter() -> void:
    super()
    entered.emit()


## Executes the process active after hit step and advances the phase state machine when complete.
func execute() -> void:
    super()
    await active_unit.resolve_effects(CombatEffects.TRIGGER.AFTER_HITTING)
    executed.emit()
    BattleController.go_to_next_phase()


## Publishes the phase result and clears transient state before advancing.
func _exit() -> void:
    super()
    exited.emit()
