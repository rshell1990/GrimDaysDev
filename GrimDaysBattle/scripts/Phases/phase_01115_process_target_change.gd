extends BattlePhase
## Battle phase responsible for process target change.
class_name BattlePhaseProcessTargetChange

## Lookup table that stores stored targets for deterministic runtime access.
var stored_targets: Dictionary


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    super()
    SignalBus.change_target.connect(on_change_target)


## Handles the change target notification for this phase process target change.
func on_change_target(old_target: BattleUnit, new_target: BattleUnit) -> void:
    stored_targets.set(old_target, new_target)


## Validates and prepares transient state when the phase becomes active.
func _enter() -> void:
    super()
    CustomLogger.hint(self, _enter, "Targets: " + str(targets), CustomLogger.LEVEL.VERY_VERBOSE)
    entered.emit()


## Executes the process target change step and advances the phase state machine when complete.
func execute() -> void:
    super()
    if stored_targets.has(targets[0]):
        targets[0] = stored_targets[targets[0]]
    executed.emit()
    BattleController.go_to_next_phase()


## Publishes the phase result and clears transient state before advancing.
func _exit() -> void:
    super()
    stored_targets.clear()
    exited.emit()
