extends BattlePhase
## Resolves one selected action through the deterministic domain pipeline.
class_name BattlePhaseResolveAction


## Publishes readiness immediately; action resolution begins in [method execute].
func _enter() -> void:
    super()
    entered.emit()


## Mutates battle state once, records ordered combat events, and hands defeat
## processing to the existing terminal/turn phases.
func execute() -> void:
    super()
    var resolution: BattleActionResolution = await phase_controller.resolve_current_action()
    var next_cargo: Dictionary = cargo if cargo is Dictionary else {}
    next_cargo["action_resolution"] = resolution
    if not resolution.success:
        executed.emit()
        BattleController.finish_battle(BattleResult.OUTCOME.ERROR, resolution.error)
        return
    next_cargo["action_resolved"] = true
    next_cargo["defeated"] = resolution.defeated.duplicate()
    executed.emit()
    BattleController.go_to_next_phase(next_cargo)


## Publishes the phase result before the state machine enters the next phase.
func _exit() -> void:
    super()
    exited.emit()
