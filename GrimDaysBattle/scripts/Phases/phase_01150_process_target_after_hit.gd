extends BattlePhase
## Battle phase responsible for process target after hit.
class_name BattlePhaseProcessTargetAfterHit


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    super()


## Validates and prepares transient state when the phase becomes active.
func _enter() -> void:
    super()
    CustomLogger.hint(self, _enter, "Targets: %s" % targets, CustomLogger.LEVEL.VERY_VERBOSE)
    entered.emit()


## Executes the process target after hit step and advances the phase state machine when complete.
func execute() -> void:
    super()
    await targets[0].resolve_effects(CombatEffects.TRIGGER.DAMAGED)
    executed.emit()
    CustomLogger.confirm(self, execute, "Target effects resolved; advancing phase.", CustomLogger.LEVEL.VERBOSE)
    BattleController.go_to_next_phase()


## Publishes the phase result and clears transient state before advancing.
func _exit() -> void:
    super()
    exited.emit()
