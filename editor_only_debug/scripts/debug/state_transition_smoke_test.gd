extends Node
## Exercises transition ordering, restoration, and the production preparation call.
var completed: bool = false


class ProbeState:
    extends GameManagerState
    var starts: int = 0
    var ends: int = 0
    var on_enter: Callable
    var on_leave: Callable

    func _ready() -> void:
        parent = get_parent()

    func on_start() -> void:
        starts += 1
        if on_enter.is_valid():
            on_enter.call()

    func on_end() -> void:
        ends += 1
        if on_leave.is_valid():
            on_leave.call()


@warning_ignore("missing_tool")


class Marker:
    extends DialogicEvent
    var visits: int = 0

    func _execute() -> void:
        visits += 1


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _run.call_deferred()


func _run() -> void:
    _check_serialization()
    await _check_production()
    completed = true
    print("STATE_TRANSITION_SMOKE_TEST: PASS") # lint:ignore debug-print -- Required test/CLI output.


func _check_serialization() -> void:
    var manager := GameManagerStates.new()
    for id in [
        GameManagerStates.STATES.BeforeGame,
        GameManagerStates.STATES.Scenario,
        GameManagerStates.STATES.TimeChanging,
        GameManagerStates.STATES.Navigation
    ]:
        var probe := ProbeState.new()
        probe.id = id
        manager.add_child(probe)
    add_child(manager)
    var initial: ProbeState = manager.current_state
    var story: ProbeState = manager.states[GameManagerStates.STATES.Scenario]
    var time: ProbeState = manager.states[GameManagerStates.STATES.TimeChanging]
    var navigation: ProbeState = manager.states[GameManagerStates.STATES.Navigation]
    var signals: Array[int] = []
    manager.transitioned.connect(
        func(id):
            assert(manager.current_state.id == id)
            signals.append(id)
    )
    # Exit hooks can request transitions, but cannot interrupt the pending commit.
    initial.on_leave = func(): manager.change_state(GameManagerStates.STATES.TimeChanging)
    manager.change_state(GameManagerStates.STATES.Scenario)
    assert(signals == [GameManagerStates.STATES.Scenario, GameManagerStates.STATES.TimeChanging])
    assert(story.starts == 1 and story.ends == 1 and time.starts == 1)
    initial.on_leave = Callable()
    var token := manager.revision
    manager.complete_state(time.id, token)
    assert(manager.current_state == story and story.starts == 1)
    assert(story.process_mode == Node.PROCESS_MODE_INHERIT)
    assert(time.process_mode == Node.PROCESS_MODE_DISABLED)
    manager.change_state(time.id)
    manager.complete_state(time.id, token)
    assert(manager.current_state == time, "An earlier visit cannot complete this visit.")
    manager.change_state(story.id)
    assert(manager.current_state == story)
    # Entry and notification callbacks also queue behind the current transition.
    story.on_enter = func(): manager.change_state(navigation.id)
    manager.change_state(time.id)
    manager.change_state(story.id)
    assert(manager.current_state == navigation and navigation.starts == 1)
    story.on_enter = Callable()
    var redirect = func(id):
        if id == story.id:
            manager.change_state(time.id)
    manager.transitioned.connect(redirect)
    manager.change_state(story.id)
    assert(manager.current_state == time)
    manager.transitioned.disconnect(redirect)
    var starts := story.starts
    manager.restore_state(story.id, navigation.id)
    assert(manager.current_state == story and manager.last_state == navigation)
    assert(story.starts == starts, "Loading must not replay entry actions.")
    var revision := manager.revision
    manager.change_state(story.id)
    assert(manager.revision == revision, "Same-state requests are idempotent.")
    manager.restart_last_state_on_end()
    assert(manager.current_state == navigation and navigation.starts == 2)
    var previous := manager.last_state
    manager.restart_current_state()
    assert(manager.current_state == navigation and manager.last_state == previous)
    assert(navigation.starts == 3)
    manager.queue_free()


func _check_production() -> void:
    var manager := GameManager.state_manager
    var notifications: Array[int] = []
    var observer = func(id):
        assert(GameManager.state == id and manager.current_state.id == id)
        assert(GameManager.last_state == manager.last_state.id)
        notifications.append(id)
    GameManager.state_changed.connect(observer)
    GameManager.change_state(GameManagerStates.STATES.ScenarioSequence)
    GameManager.change_state(GameManagerStates.STATES.TimeChanging)
    var old_token := manager.revision
    GameManager.change_state(GameManagerStates.STATES.Scenario)
    assert(GameManager.state == GameManagerStates.STATES.Scenario)
    assert(manager.current_state.id == GameManager.state)
    assert(not Dialogic.paused)
    # Late completion and the pending UIDirector timer must leave a new pause alone.
    Dialogic.paused = true
    manager.complete_state(GameManagerStates.STATES.TimeChanging, old_token)
    await get_tree().create_timer(VNAnimationTimes.STANDARD + 0.2).timeout
    assert(Dialogic.paused and GameManager.state == GameManagerStates.STATES.Scenario)
    assert(not UIDirector.time_passage_ui.visible)
    Dialogic.paused = false
    # Completion resumes the preceding state without replaying its entry behavior.
    GameManager.change_state(GameManagerStates.STATES.TimeChanging)
    manager.complete_state(GameManagerStates.STATES.TimeChanging, manager.revision)
    assert(GameManager.state == GameManagerStates.STATES.Scenario and not Dialogic.paused)
    # The real UI's equal-time completion resumes its owner; no unscoped signal.
    var time_state: TimeChangeState = manager.states[GameManagerStates.STATES.TimeChanging]
    time_state.start_time = SystemAdministrators.current_time()
    GameManager.change_state(GameManagerStates.STATES.TimeChanging)
    await get_tree().create_timer(VNAnimationTimes.STANDARD + 0.2).timeout
    assert(GameManager.state == GameManagerStates.STATES.Scenario and not Dialogic.paused)
    # Interrupt after visual work has begun, then wait for its old coroutine.
    time_state.start_time = (
        TimeAdministrator.TIMES.Bedtime
        if SystemAdministrators.current_time() != TimeAdministrator.TIMES.Bedtime
        else TimeAdministrator.TIMES.Dawn
    )
    GameManager.change_state(GameManagerStates.STATES.TimeChanging)
    await get_tree().create_timer(VNAnimationTimes.STANDARD * 2 + 0.1).timeout
    assert(UIDirector.time_passage_ui.visible)
    GameManager.change_state(GameManagerStates.STATES.Scenario)
    Dialogic.paused = true
    await get_tree().create_timer(VNAnimationTimes.FAST + 0.2).timeout
    assert(not UIDirector.time_passage_ui.visible and Dialogic.paused)
    Dialogic.paused = false
    # Both save restoration and legacy ID assignment keep node and ID coherent.
    manager.restore_state(GameManagerStates.STATES.ScenarioSequence, GameManagerStates.STATES.Scenario)
    assert(GameManager.state == manager.current_state.id)
    GameManager.state = GameManagerStates.STATES.Scenario
    assert(GameManager.state == manager.current_state.id)
    GameManager.state_changed.disconnect(observer)
    var event := DialogicCallEvent.new()
    event.autoload_name = "UIDirector"
    event.method = "show_story_party_preparation"
    event.event_node_ready = true
    var marker := Marker.new()
    marker.event_node_ready = true
    Dialogic.current_timeline = DialogicTimeline.new()
    Dialogic.current_timeline_events = [event, marker]
    Dialogic.current_event_idx = -1
    Dialogic.handle_event(0)
    await get_tree().process_frame
    var session := UIDirector.party_preparation
    assert(session and session.active and session.panel.is_visible_in_tree())
    assert(get_tree().paused and Dialogic.paused and marker.visits == 0)
    session.close()
    await get_tree().process_frame
    assert(marker.visits == 1 and not Dialogic.paused and not get_tree().paused)
    await Dialogic.clear()
