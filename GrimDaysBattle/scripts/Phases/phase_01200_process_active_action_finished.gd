extends BattlePhase
## Battle phase responsible for process active action finished.
class_name BattlePhaseProcessActiveActionFinished


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    super()


## Validates and prepares transient state when the phase becomes active.
func _enter() -> void:
    super()
    if (cargo is Dictionary and cargo.get("action_resolved", false)) or targets.size() < 2:
        SignalBus.unit_move_to_original_position.emit(active_unit)
    entered.emit()


## Executes the process active action finished step and advances the phase state machine when complete.
func execute() -> void:
    super()
    var already_resolved: bool = cargo is Dictionary and cargo.get("action_resolved", false) == true
    if not already_resolved and active_unit.effect_manager.has_effects_to_trigger(CombatEffects.TRIGGER.PROCESS_OVER):
        await active_unit.resolve_effects(CombatEffects.TRIGGER.PROCESS_OVER)
    executed.emit()
    BattleController.go_to_next_phase(cargo if already_resolved else null)


## Publishes the phase result and clears transient state before advancing.
func _exit() -> void:
    super()
    exited.emit()
