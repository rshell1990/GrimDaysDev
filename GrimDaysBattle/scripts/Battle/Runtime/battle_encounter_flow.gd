extends Node
## Runs the battle's turns, from choosing an action to applying its results.
## Other scripts manage battle setup, effects, combat calculations and displays.
class_name BattleEncounterFlow

## Asks the action menu to offer these actions for the supplied unit and turn number.
signal action_required(turn_id: int, actor: BattleUnit, actions: Array[ActionTemplate])
## Announces a change to the current turn or input step so displays can refresh.
signal state_changed
## Announces the resolved action after effects and return movement finish.
signal action_completed(resolution: BattleActionResolution)

## Named choices for state: [code]STOPPED[/code], [code]ADVANCING[/code], [code]ACTION[/code],
## [code]TARGETS[/code], [code]RESOLVING[/code].
enum STATE { STOPPED, ADVANCING, ACTION, TARGETS, RESOLVING }
## Current step of the turn. STOPPED prevents work waiting on animations or effects from continuing.
var state: STATE = STATE.STOPPED
## Turn number that increases whenever a unit starts a turn, used to ignore button presses from
## earlier turns.
var turn_id: int = 0
## Unit currently taking a turn, or null between turns and after stopping.
var active_unit: BattleUnit
## Most recent error that stopped the battle, also recorded in the battle result.
var last_error: String = ""
## Optional local presentation, awaited before the first turn of a round.
var round_presentation: Callable
## Optional UI barrier before movement, costs, effects or command progression.
var action_presentation: Callable
var flee_allowed: bool = true
var fleeing: bool = false
## Battle manager supplied to start; provides the units, turn list and result.
var coordinator: BattleCoordinator
## Battle display supplied to start; shows units and lets the player choose targets.
var stage: BattleVisualStage
## Battle attempt number remembered while waiting, so work from an old attempt can be ignored.
var _session: int = -1
## Chosen action waiting for targets to be selected or its combat results to be calculated.
var _action: ActionTemplate
## Targets currently being chosen. Copied before the action runs so later selection changes cannot
## affect it.
var _targets: Array[BattleUnit] = []
## Helper that runs this battle's round-end and defeat effects.
var _effects := BattleEncounterEffects.new()
## Child node that calculates and applies action costs, hits and effects.
var _resolver := BattleActionResolver.new()
## Child node that moves the acting unit before and after combat results are applied.
var _presentation := BattleActionPresentation.new()
## Bounded visual feedback, separate from movement and domain mutation.
var _feedback := BattleCombatPresentation.new()


## Adds the combat-calculation and movement helpers as children so they are removed with this node.
func _init() -> void:
    add_child(_resolver)
    add_child(_presentation)
    add_child(_feedback)


## Starts taking turns after the battle's units and their displays are ready.
## Returns false if the battle or any required display is unavailable.
func start(encounter: BattleCoordinator, visual_stage: BattleVisualStage) -> bool:
    if state != STATE.STOPPED or _resolver.resolving or not is_inside_tree():
        return false
    if not is_instance_valid(encounter) or not encounter.is_current_session(encounter.session_id):
        return false
    if not is_instance_valid(visual_stage):
        return false
    for unit in encounter.roster.get_participants():
        if not visual_stage.get_unit_display(unit):
            return false
    coordinator = encounter
    stage = visual_stage
    _session = coordinator.session_id
    for unit in coordinator.roster.get_participants():
        unit.control_changed.connect(_on_control_changed.bind(unit))
        unit.forced_action_changed.connect(_on_forced_action_changed.bind(unit))
    fleeing = false
    _effects.reset()
    coordinator.battle_clearing.connect(_on_clearing)
    coordinator.battle_finished.connect(_on_finished)
    stage.target_added.connect(_on_target_added)
    stage.target_removed.connect(_on_target_removed)
    stage.tree_exiting.connect(stop)
    _set_state(STATE.ADVANCING)
    _advance.call_deferred(_session)
    return true


## Accepts a usable player action only during the matching active turn; returns whether selection began.
func choose_action(input_turn: int, action: ActionTemplate) -> bool:
    if state != STATE.ACTION or input_turn != turn_id or not _current(_session):
        return false
    if not active_unit.player_controlled or not active_unit.can_use_action(action):
        return false
    return _select_action(action)


## Retained rejection boundary for obsolete voluntary Pass callers.
func pass_turn(_input_turn: int) -> bool:
    # No voluntary Pass. Madness Catatonic resolves through its validated effect action.
    return false


func can_choose_command(command: int) -> bool:
    if (
        state != STATE.ACTION
        or not _current(_session)
        or not is_instance_valid(active_unit)
        or active_unit.is_stunned()
        or not active_unit.player_controlled
        or active_unit.has_madness()
        or active_unit.get_forced_action_effect()
        or fleeing
    ):
        return false
    match command:
        CombatActions.COMMAND.DEFEND:
            return BattleDefend.can_defend(active_unit)
        CombatActions.COMMAND.WAIT:
            return coordinator.turn_order.can_wait(active_unit)
        CombatActions.COMMAND.FLEE:
            return flee_allowed and active_unit in coordinator.roster.get_allies()
    return false


func choose_command(input_turn: int, command: int) -> bool:
    if input_turn != turn_id or not can_choose_command(command):
        return false
    if command == CombatActions.COMMAND.FLEE:
        fleeing = true
    _set_state(STATE.RESOLVING)
    _resolve_command.call_deferred(_session, command)
    return true


func _resolve_command(token: int, command: int) -> void:
    if not _current(token):
        return
    var actor := active_unit
    var continuation := _current.bind(token)
    if action_presentation.is_valid():
        await action_presentation.call(continuation)
    if not continuation.call():
        return
    if command == CombatActions.COMMAND.WAIT:
        if coordinator.turn_order.wait_turn(actor):
            active_unit = null
            _set_state(STATE.ADVANCING)
            _advance.call_deferred(token)
        return
    if command == CombatActions.COMMAND.DEFEND:
        await BattleDefend.apply(actor, continuation)
    if not continuation.call():
        return
    # Commands spend a normal action, including ordinary action-finished hooks.
    await actor.resolve_effects(CombatEffects.TRIGGER.PROCESS_OVER, &"", continuation)
    if not continuation.call():
        return
    var events := await _effects.process_defeats(coordinator.roster, continuation, &"", _result_feedback(continuation))
    if not continuation.call():
        return
    coordinator.current_result.combat_events.append_array(events)
    await _feedback.play_events(stage, events, continuation)
    if not continuation.call() or _finish_if_over():
        return
    if command == CombatActions.COMMAND.FLEE and actor.is_active:
        var chance: float = 35.0
        for stat_id in [CombatStats.STATS.Evasion, CombatStats.STATS.LuckyEvasion]:
            var stat := actor.get_stat(stat_id)
            if stat:
                chance += stat.Current
        if actor.randomizer.roll(chance):
            coordinator.roster.escape(actor)
            var display := stage.get_unit_display(actor)
            if display:
                display.hide()
    if not _finish_if_over():
        _end_turn()


## Clears chosen targets and lets the player choose another action without spending resources.
func cancel_selection() -> void:
    if state != STATE.TARGETS or not _current(_session):
        return
    stage.clear_target_selection(_session)
    _targets.clear()
    _action = null
    _request_action()


## Waits until the next frame, handles defeats and round endings, then asks the player for an action
## or chooses one for a computer-controlled unit.
func _advance(token: int) -> void:
    # call_deferred alone can recurse within the same idle flush when all units
    # pass. Always yield a frame so input, cleanup and presentation can run.
    await get_tree().process_frame
    if not _current(token):
        return
    var continuation := _current.bind(token)
    var lifecycle_id := StringName("%s:%s:advance:%s" % [coordinator.current_result.encounter_id, token, turn_id])
    var defeat_events := await _effects.process_defeats(
        coordinator.roster, continuation, lifecycle_id, _result_feedback(continuation)
    )
    if not _current(token):
        return
    coordinator.current_result.combat_events.append_array(defeat_events)
    await _feedback.play_events(stage, defeat_events, continuation)
    if not _current(token) or _finish_if_over():
        return
    if coordinator.turn_order.get_active_unit() == null:
        if coordinator.current_result.rounds > 0:
            var round_id := StringName(
                "%s:%s:round:%s" % [coordinator.current_result.encounter_id, token, coordinator.current_result.rounds]
            )
            var round_events := await _effects.end_round(
                coordinator.roster, continuation, round_id, _result_feedback(continuation)
            )
            if not _current(token):
                return
            SignalBus.tick.emit(round_id)
            coordinator.current_result.combat_events.append_array(round_events)
            await _feedback.play_events(stage, round_events, continuation)
            if not _current(token) or _finish_if_over():
                return
        coordinator.begin_round(token)
        if round_presentation.is_valid():
            await round_presentation.call(coordinator.current_result.rounds, continuation)
            if not _current(token):
                return
    active_unit = coordinator.turn_order.get_active_unit()
    if not active_unit:
        _fail("Encounter has no active combatants.")
        return
    var first_start := coordinator.record_turn_started(token)
    turn_id += 1
    if first_start:
        active_unit.on_turn_started()
        if not active_unit.is_stunned():
            await coordinator.process_lucidity_turn(active_unit, token)
    if not _current(token):
        return
    # A break action/effect can defeat the actor or other participants before normal selection.
    var break_events := await _effects.process_defeats(
        coordinator.roster,
        continuation,
        StringName("%s:lucidity:%s" % [lifecycle_id, turn_id]),
        _result_feedback(continuation)
    )
    if not _current(token):
        return
    coordinator.current_result.combat_events.append_array(break_events)
    await _feedback.play_events(stage, break_events, continuation)
    if not _current(token) or _finish_if_over():
        return
    if not active_unit.is_active:
        _end_turn()
        return
    _choose_controller_action(_session, turn_id)


## Also used when an uncommitted player choice hands over to AI. This does not
## start another turn, tick cooldowns again or pay the abandoned action's cost.
func _choose_controller_action(token: int, input_turn: int) -> void:
    if not _current(token) or turn_id != input_turn or state != STATE.ADVANCING:
        return
    if active_unit.is_stunned():
        _set_state(STATE.RESOLVING)
        _resolve_command.call_deferred(token, CombatActions.COMMAND.NONE)
        return
    var forced := active_unit.get_forced_action_effect()
    if forced:
        if active_unit.can_use_action(forced.definition.action) and _select_action(forced.definition.action):
            return
        # An impossible mandate spends the turn's finish hooks, never falls back to a voluntary action.
        _set_state(STATE.RESOLVING)
        _resolve_command.call_deferred(token, CombatActions.COMMAND.NONE)
        return
    if (
        fleeing
        and active_unit in coordinator.roster.get_allies()
        and active_unit.player_controlled
        and not active_unit.has_madness()
    ):
        _set_state(STATE.RESOLVING)
        _resolve_command.call_deferred(token, CombatActions.COMMAND.FLEE)
        return
    if active_unit.player_controlled and not active_unit.has_madness():
        _request_action()
        return
    var gang_choice := StreetBulliesAI.choose(active_unit, coordinator.current_result.combat_events)
    if gang_choice.is_empty():
        gang_choice = SacredDutyAI.choose(active_unit, coordinator.current_result.combat_events)
    if not gang_choice.is_empty():
        _action = gang_choice.action
        _targets.assign(gang_choice.targets)
        _commit_action()
        return
    var choices := _available_actions()
    while not choices.is_empty():
        var action: ActionTemplate = (
            active_unit.randomizer.pick_random(choices) if active_unit.has_madness() else choices[0]
        )
        choices.erase(action)
        if _select_action(action):
            return
    _fail("No legal basic action or forced action is available for the active unit.")


## A committed action finishes normally. Pending player input is invalidated
## immediately, then AI selection happens outside the stat/effect signal stack.
func _on_control_changed(player_has_control: bool, unit: BattleUnit) -> void:
    if (
        player_has_control
        or unit != active_unit
        or not _current(_session)
        or state not in [STATE.ACTION, STATE.TARGETS]
    ):
        return
    stage.clear_target_selection(_session)
    _targets.clear()
    _action = null
    _set_state(STATE.ADVANCING)
    _choose_controller_action.call_deferred(_session, turn_id)


## Invalidate only uncommitted selections; resolving actions finish using their snapshot.
func _on_forced_action_changed(unit: BattleUnit) -> void:
    if unit != active_unit or not _current(_session) or state not in [STATE.ACTION, STATE.TARGETS]:
        return
    stage.clear_target_selection(_session)
    _targets.clear()
    _action = null
    _set_state(STATE.ADVANCING)
    _choose_controller_action.call_deferred(_session, turn_id)


## Returns the actor's usable owned actions that have at least one valid target.
func _available_actions() -> Array[ActionTemplate]:
    var actions: Array[ActionTemplate] = []
    for action in active_unit.get_owned_actions():
        if active_unit.can_use_action(action) and not _candidates(action).is_empty():
            actions.append(action)
    if active_unit.player_controlled:
        for action in BattleItemAction.available(active_unit):
            if active_unit.can_use_action(action) and not _candidates(action).is_empty():
                actions.append(action)
    actions.append_array(BattleMadnessAction.available(active_unit))
    return actions


## Starts action selection and tells the menu the turn number, acting unit and available actions.
func _request_action() -> void:
    _set_state(STATE.ACTION)
    action_required.emit(turn_id, active_unit, _available_actions())


## Returns active encounter participants allowed by the action's targeting rules.
func _candidates(action: ActionTemplate) -> Array[BattleUnit]:
    var candidates: Array[BattleUnit] = []
    for unit in coordinator.roster.get_all_active_units():
        if CombatActions.valid_target(action, active_unit, unit):
            candidates.append(unit)
    return candidates


## Lets the player choose targets, or chooses them automatically and starts the action. Returns
## false if no selection can be made.
func _select_action(action: ActionTemplate) -> bool:
    var candidates := _candidates(action)
    if candidates.is_empty():
        return false
    _action = action
    _targets.clear()
    if active_unit.has_madness():
        _targets.assign(CombatActions.madness_targets(action, active_unit))
    elif action.target in [CombatActions.TARGET.ALLY, CombatActions.TARGET.FOE]:
        if active_unit.player_controlled and not active_unit.get_forced_action_effect():
            if not stage.select_targets(_session, active_unit, action):
                return false
            _set_state(STATE.TARGETS)
            return true
        while not candidates.is_empty() and _targets.size() < maxi(action.target_amount, 1):
            var target: BattleUnit = active_unit.randomizer.pick_random(candidates)
            _targets.append(target)
            candidates.erase(target)
    else:
        _targets.assign(CombatActions.set_targets(action, active_unit).targets)
    if _targets.is_empty():
        return false
    _commit_action()
    return true


## Adds an allowed target for this battle attempt and starts the action once enough targets have
## been chosen.
func _on_target_added(token: int, unit: BattleUnit) -> void:
    if state != STATE.TARGETS or not _current(token) or unit in _targets or unit not in _candidates(_action):
        return
    if not active_unit.player_controlled:
        return
    _targets.append(unit)
    if _targets.size() >= mini(maxi(_action.target_amount, 1), _candidates(_action).size()):
        _commit_action()


## Removes a selected target only while the matching session is choosing targets.
func _on_target_removed(token: int, unit: BattleUnit) -> void:
    if state == STATE.TARGETS and _current(token):
        _targets.erase(unit)


## Stops target selection, copies the acting unit, action and target list into a request, and
## schedules the action to run.
func _commit_action() -> void:
    stage.clear_target_selection(_session)
    _set_state(STATE.RESOLVING)
    # Snapshot immediately; input can never mutate an in-flight action.
    var request := (
        BattleActionRequest
        . new(
            StringName("%s:%s:turn:%s" % [coordinator.current_result.encounter_id, _session, turn_id]),
            active_unit,
            _action,
            _targets,
        )
    )
    _resolve.call_deferred(_session, request)


## Waits for approach movement, applies combat results and defeat effects, then moves the unit back.
## Checks after each wait that this is still the current battle attempt.
func _resolve(token: int, request: BattleActionRequest) -> void:
    var continuation := _current.bind(token)
    if not continuation.call():
        return
    if action_presentation.is_valid():
        await action_presentation.call(continuation)
    if not continuation.call():
        return
    if not request.action is BattleItemAction and not request.action is BattleMadnessAction:
        await _presentation.approach(stage, request.actor, request.targets[0], continuation)
    if not continuation.call():
        return
    var timing := BattleActionContext.new()
    await _feedback.attack(stage, request, continuation, timing)
    if not continuation.call():
        return
    var immediate_feedback := _result_feedback(continuation)
    _resolver.operation_resolved.connect(immediate_feedback)
    var resolution: BattleActionResolution = await _resolver.resolve(request, continuation, timing)
    _resolver.operation_resolved.disconnect(immediate_feedback)
    if not continuation.call():
        return
    if not resolution.success:
        _fail(resolution.error)
        return
    coordinator.current_result.combat_events.append_array(resolution.events)
    var defeat_events := await _effects.process_defeats(
        coordinator.roster, continuation, request.request_id, _result_feedback(continuation)
    )
    if not continuation.call():
        return
    coordinator.current_result.combat_events.append_array(defeat_events)
    await _feedback.play_events(stage, resolution.events + defeat_events, continuation)
    if not continuation.call():
        return
    await _presentation.return_actor(continuation)
    if not continuation.call():
        return
    action_completed.emit(resolution)
    if continuation.call() and not _finish_if_over():
        _end_turn()


## Clears the selection, removes the actual actor from this round and schedules the next turn.
func _end_turn() -> void:
    _targets.clear()
    _action = null
    # Remove the actual actor, even if defeat hooks changed the active-unit view.
    coordinator.turn_order.remove_defeated([active_unit])
    active_unit = null
    _set_state(STATE.ADVANCING)
    _advance.call_deferred(_session)


## Ends the battle if either original side has no units left able to fight; returns true if the
## battle ended.
## Temporary team changes do not change which side counts as winning or losing.
func _finish_if_over() -> bool:
    # Allegiance/control effects change targeting, never encounter membership.
    var allies_empty := not coordinator.roster.get_allies().any(
        func(unit): return is_instance_valid(unit) and unit.is_active and coordinator.roster.is_present(unit)
    )
    var foes_empty := not coordinator.roster.get_foes().any(
        func(unit): return is_instance_valid(unit) and unit.is_active
    )
    if not allies_empty and not foes_empty:
        return false
    var outcome := (
        BattleResult.OUTCOME.VICTORY
        if fleeing and foes_empty
        else (
            BattleResult.OUTCOME.DRAW
            if allies_empty and foes_empty
            else (BattleResult.OUTCOME.DEFEAT if allies_empty else BattleResult.OUTCOME.VICTORY)
        )
    )
    coordinator.finish(_session, outcome)
    return true


## Records the error and ends the battle with an ERROR result.
func _fail(message: String) -> void:
    last_error = message
    coordinator.finish(_session, BattleResult.OUTCOME.ERROR, message)


## Checks that the attempt number still matches and that the battle and its display are still
## running.
func _current(token: int) -> bool:
    return (
        state != STATE.STOPPED
        and token == _session
        and is_instance_valid(stage)
        and stage.is_inside_tree()
        and is_instance_valid(coordinator)
        and coordinator.is_current_session(token)
    )


## Sets the current turn step and announces the change, even if the step is unchanged.
func _set_state(value: STATE) -> void:
    state = value
    state_changed.emit()


## Stops waiting work and movement, stops listening for battle notifications, and clears the current
## action and targets.
func stop() -> void:
    _set_state(STATE.STOPPED)
    _presentation.cancel()
    _feedback.cancel()
    if is_instance_valid(stage):
        stage.clear_target_selection(_session)
        if stage.tree_exiting.is_connected(stop):
            stage.tree_exiting.disconnect(stop)
        if stage.target_added.is_connected(_on_target_added):
            stage.target_added.disconnect(_on_target_added)
            stage.target_removed.disconnect(_on_target_removed)
    if is_instance_valid(coordinator):
        for unit in coordinator.roster.get_participants():
            var forced_callback := _on_forced_action_changed.bind(unit)
            if is_instance_valid(unit) and unit.forced_action_changed.is_connected(forced_callback):
                unit.forced_action_changed.disconnect(forced_callback)
            var callback := _on_control_changed.bind(unit)
            if is_instance_valid(unit) and unit.control_changed.is_connected(callback):
                unit.control_changed.disconnect(callback)
        if coordinator.battle_clearing.is_connected(_on_clearing):
            coordinator.battle_clearing.disconnect(_on_clearing)
            coordinator.battle_finished.disconnect(_on_finished)
    active_unit = null
    _targets.clear()
    _action = null


## Stops the flow when its own coordinator session begins cleanup.
func _on_clearing(token: int) -> void:
    if token == _session:
        stop()


## Stops the flow when its own coordinator session finishes.
func _on_finished(token: int, _result: BattleResult) -> void:
    _on_clearing(token)


## Stops input and pending presentation when the flow leaves the scene tree.
func _exit_tree() -> void:
    stop()


## Capture the stage and attempt guard so delayed work cannot present on a newer battle.
func _result_feedback(continuation: Callable) -> Callable:
    var feedback_stage := stage
    return func(event: BattleCombatEvent):
        if continuation.is_valid() and continuation.call() and is_instance_valid(feedback_stage):
            _feedback.present_result(feedback_stage, event)
