extends BattlePhase
## Battle phase responsible for get action targets.
class_name BattlePhaseGetActionTargets

## Emitted when targets picked.
signal targets_picked
## Whether the selection complete condition currently holds.
var selection_complete: bool
## Whether the selection cancelled condition currently holds.
var selection_cancelled: bool
## Runtime cancellation phase state used by this phase get action targets.
var cancellation_phase: Combat.BATTLE_STATES


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    super()


## Validates and prepares transient state when the phase becomes active.
func _enter() -> void:
    super()
    selection_complete = false
    selection_cancelled = false
    cancellation_phase = Combat.BATTLE_STATES.PROCESS_ACTIVE_ACTION_FINISHED
    if cargo is not Dictionary:
        cargo = {}
    cargo["targets"] = []
    _connect_selection_signals()
    if not selected_action or not active_unit:
        complete_selection(true)
        entered.emit()
        return
    if not active_unit.can_use_action(selected_action):
        cancellation_phase = (
            Combat.BATTLE_STATES.GIVE_PLAYER_CONTROL
            if active_unit.player_controlled
            else Combat.BATTLE_STATES.PROCESS_ACTIVE_ACTION_FINISHED
        )
        complete_selection(true)
        entered.emit()
        return
    if active_unit.has_madness():
        cargo.targets.assign(CombatActions.madness_targets(selected_action, active_unit))
        complete_selection(cargo.targets.is_empty())
    elif selected_action.target in [CombatActions.TARGET.ALLY, CombatActions.TARGET.FOE]:
        CustomLogger.hint(self, _enter, "Determining target-selection controller.", CustomLogger.LEVEL.VERY_VERBOSE)
        if not active_unit.player_controlled:
            get_targets_from_ai()
    else:
        set_targets(CombatActions.set_targets(selected_action, active_unit).targets)

    entered.emit()


## Connects selection signals for this phase get action targets.
func _connect_selection_signals() -> void:
    if not SignalBus.add_target.is_connected(on_target_sent):
        SignalBus.add_target.connect(on_target_sent)
    if not SignalBus.remove_target.is_connected(on_remove_target):
        SignalBus.remove_target.connect(on_remove_target)
    if not SignalBus.clear_selected_targets.is_connected(on_clear_targets):
        SignalBus.clear_selected_targets.connect(on_clear_targets)


## Handles the remove target notification for this phase get action targets.
func on_remove_target(unit: BattleUnit) -> void:
    if selection_complete or not cargo or not cargo.has("targets"):
        return
    cargo.targets.erase(unit)


## Handles the clear targets notification for this phase get action targets.
func on_clear_targets() -> void:
    if selection_complete:
        return
    if cargo is Dictionary:
        cargo["targets"] = []
    if active_unit and active_unit.player_controlled:
        cancellation_phase = Combat.BATTLE_STATES.GIVE_PLAYER_CONTROL
    complete_selection(true)


## Handles Back independently from any unit's mouse region. The first press
## removes the most recently selected target; pressing Back with none selected
## cancels targeting and returns control to the action menu.
func on_back_requested() -> void:
    if selection_complete:
        return
    if cargo is Dictionary and not cargo.get("targets", []).is_empty():
        cargo.targets.pop_back()
        return
    on_clear_targets()


## Handles unconsumed input events for this phase get action targets.
func _unhandled_input(event: InputEvent) -> void:
    if (
        not event.is_action_released("back")
        or selection_complete
        or not phase_controller
        or phase_controller.current_phase != id
        or not active_unit
        or not active_unit.player_controlled
    ):
        return
    on_back_requested()
    get_viewport().set_input_as_handled()


## Returns targets from ai for this phase get action targets.
func get_targets_from_ai() -> void:
    CustomLogger.hint(self, get_targets_from_ai, "Requesting AI targets.", CustomLogger.LEVEL.VERY_VERBOSE)
    var selected := active_unit.get_targets_from_ai(selected_action)
    var ai_targets: Array = selected.get("targets", []) if selected is Dictionary else []
    set_targets(ai_targets)
    CustomLogger.hint(self, get_targets_from_ai, "AI selection cargo: %s" % cargo, CustomLogger.LEVEL.VERY_VERBOSE)
    CustomLogger.confirm(self, get_targets_from_ai, "AI targets selected.", CustomLogger.LEVEL.VERBOSE)


## Sets targets for this phase get action targets.
func set_targets(candidates: Array) -> void:
    for candidate in candidates:
        on_target_sent(candidate)
    if cargo.targets.is_empty():
        complete_selection(true)
    elif selected_action.target not in [CombatActions.TARGET.ALLY, CombatActions.TARGET.FOE]:
        complete_selection()


## Handles the target sent notification for this phase get action targets.
func on_target_sent(unit: BattleUnit) -> void:
    var validate_target: Callable = CombatActions.valid_target
    if selection_complete or not validate_target.call(selected_action, active_unit, unit):
        return
    if unit in cargo.targets:
        return
    cargo.targets.append(unit)
    if cargo.targets.size() >= maxi(selected_action.target_amount, 1):
        complete_selection()


## Completes selection for this phase get action targets.
func complete_selection(cancelled: bool = false) -> void:
    if selection_complete:
        return
    selection_complete = true
    selection_cancelled = cancelled
    targets_picked.emit()
    SignalBus.target_selected.emit()


## Executes the get action targets step and advances the phase state machine when complete.
func execute() -> void:
    super()
    CustomLogger.hint(self, execute, "Waiting for target selection.", CustomLogger.LEVEL.VERY_VERBOSE)
    if not selection_complete:
        await targets_picked
    CustomLogger.confirm(self, execute, "Target selection completed.", CustomLogger.LEVEL.VERBOSE)
    if selection_cancelled:
        next_phase = cancellation_phase
    else:
        # The deterministic resolver owns cost and cooldown mutation. Selection
        # only validates affordability so cancellation remains free.
        SignalBus.target_set.emit()
        (
            CustomLogger
            . confirm(
                self,
                execute,
                "Selected action: %s (%s)." % [selected_action.display_name, selected_action.id],
                CustomLogger.LEVEL.VERBOSE,
            )
        )
    executed.emit()
    BattleController.go_to_next_phase(cargo)


## Publishes the phase result and clears transient state before advancing.
func _exit() -> void:
    super()
    if SignalBus.add_target.is_connected(on_target_sent):
        SignalBus.add_target.disconnect(on_target_sent)
    if SignalBus.remove_target.is_connected(on_remove_target):
        SignalBus.remove_target.disconnect(on_remove_target)
    if SignalBus.clear_selected_targets.is_connected(on_clear_targets):
        SignalBus.clear_selected_targets.disconnect(on_clear_targets)
    exited.emit()
