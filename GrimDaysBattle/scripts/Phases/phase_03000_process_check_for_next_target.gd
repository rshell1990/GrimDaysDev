extends BattlePhase
## Battle phase responsible for process check for next target.
class_name BattlePhaseProcessCheckForNextTarget


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    super()


## Validates and prepares transient state when the phase becomes active.
func _enter() -> void:
    super()
    var has_next := phase_controller.has_next_target() if phase_controller else targets.size() > 1
    if not has_next:
        CustomLogger.hint(self, _enter, "Switching away from combat camera.", CustomLogger.LEVEL.VERY_VERBOSE)
        SignalBus.switch_away_from_combat_camera.emit()
    else:
        (
            CustomLogger
            . hint(
                self,
                _enter,
                "Targets remaining: %s" % [targets],
                CustomLogger.LEVEL.VERY_VERBOSE,
            )
        )
    entered.emit()


## Executes the process check for next target step and advances the phase state machine when complete.
func execute() -> void:
    super()
    # BattleActionResolver processes the immutable target batch in one request.
    # Legacy per-target traversal remains available for callers without this flag.
    if cargo is Dictionary and cargo.get("action_resolved", false):
        finish_action()
        return
    var advanced := phase_controller.advance_target() if phase_controller else targets.size() > 1
    if advanced:
        if not phase_controller:
            targets = targets.slice(1)
        next_phase = Combat.BATTLE_STATES.PROCESS_TARGET_CHECK_BEFORE_HIT
        executed.emit()
        BattleController.go_to_next_phase()
        return

    # The actor owns the action until every selected target has been processed.
    # Only the final target advances turn order.
    finish_action()


## Releases action state and advances the turn exactly once.
func finish_action() -> void:
    if phase_controller:
        phase_controller.clear_action_targets(true)
        phase_controller.selected_action = null
    targets.clear()
    BattleController.set_next_unit()
    if BattleController.get_units_in_foe_holder().is_empty():
        next_phase = Combat.BATTLE_STATES.VICTORY
    elif BattleController.get_units_in_ally_holder().is_empty():
        next_phase = Combat.BATTLE_STATES.DEFEAT
    elif not BattleController.get_active_unit():
        next_phase = Combat.BATTLE_STATES.TRIGGER_ROUND_END_EFFECTS
    executed.emit()
    BattleController.go_to_next_phase()


## Publishes the phase result and clears transient state before advancing.
func _exit() -> void:
    super()
    exited.emit()
