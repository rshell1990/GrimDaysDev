extends BattlePhase
## Battle phase responsible for process check if target hit.
class_name BattlePhaseCheckIfTargetHit


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    super()


## Validates and prepares transient state when the phase becomes active.
func _enter() -> void:
    super()
    CustomLogger.hint(self, _enter, "Targets: %s" % targets, CustomLogger.LEVEL.VERY_VERBOSE)
    entered.emit()


## Executes the process check if target hit step and advances the phase state machine when complete.
func execute() -> void:
    super()
    if selected_action.always_hits:
        finish_execution()
        return
    if not active_unit.check_if_hit(targets[0]):
        SignalBus.dodged.emit(targets[0])
        next_phase = Combat.BATTLE_STATES.PROCESS_ACTIVE_ACTION_FINISHED

    finish_execution()


## Finishes execution for this phase check if target hit.
func finish_execution() -> void:
    executed.emit()
    BattleController.go_to_next_phase()


## Publishes the phase result and clears transient state before advancing.
func _exit() -> void:
    super()
    exited.emit()
