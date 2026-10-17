## Exercises the authored arrival-to-room handoff through the real event and Dialogic systems.
extends Node

const ARRIVAL = preload("res://GrimDaysVN/resources/events/1_0000_start.tres")
const ROOM = preload("res://GrimDaysVN/resources/events/1_0010_livingroom.tres")
const EVENT_MASTER = preload("res://GrimDaysVN/resources/events/all_events_prototype_1.tres")

var room_requests: int = 0
var room_starts: int = 0


func _ready() -> void:
    get_tree().create_timer(15.0).timeout.connect(_on_timeout)
    _run.call_deferred()


func _run() -> void:
    var repository: GameEventsRepository = Repositories.get_repository(RepositoryTypes.EVENTS)
    assert(repository.resource == EVENT_MASTER)
    assert(SystemAdministrators.find_event_by_id(ARRIVAL.id) == ARRIVAL)
    assert(SystemAdministrators.find_event_by_id(ROOM.id) == ROOM)
    for location in NavigationAdministrator.LOCATIONS:
        for time in TimeAdministrator.TIMES.values():
            for day in TimeAdministrator.DAYS:
                assert(not ARRIVAL in repository.master[location][time][day])
                assert(not ROOM in repository.master[location][time][day])
    assert(ROOM.blocks_swap)
    VNSignalBus.event_found.connect(_on_event_found)
    Dialogic.timeline_started.connect(_on_timeline_started)
    GameManager.change_state(GameManagerStates.STATES.ScenarioSequence)
    # Skip only the opening cinematic; run the same finishing timeline and event callback.
    GameManager._on_event_found(ARRIVAL)
    await get_tree().process_frame
    Dialogic.start(ARRIVAL.finishing_timeline)
    await get_tree().process_frame
    assert(Dialogic.current_timeline == ARRIVAL.finishing_timeline)
    Dialogic.end_timeline()
    var deadline := Time.get_ticks_msec() + 5000
    while Dialogic.current_timeline != ROOM.timeline and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    assert(Dialogic.current_timeline == ROOM.timeline, "Arrival must start the room dialogue.")
    assert(GameManager.current_event == ROOM, "The replacement event must not be cleared by arrival cleanup.")
    assert(room_requests == 1 and room_starts == 1, "The room dialogue must start exactly once.")
    assert(get_tree().current_scene == self and not SceneManager.swapping, "The dialogue must continue in place.")
    await get_tree().create_timer(0.1).timeout
    assert(room_requests == 1 and room_starts == 1)
    GameManager.on_loading_sequence_start()
    await Dialogic.clear()
    await get_tree().process_frame
    print("GERANO_STORY_HANDOFF_SMOKE_TEST: PASS") # lint:ignore debug-print -- Required test/CLI output.
    get_tree().quit()


func _on_event_found(event: GameEvent) -> void:
    if event == ROOM:
        room_requests += 1


func _on_timeline_started() -> void:
    if Dialogic.current_timeline == ROOM.timeline:
        room_starts += 1


func _on_timeout() -> void:
    push_error("GERANO_STORY_HANDOFF_SMOKE_TEST: timed out before the handoff checks completed.")
    get_tree().quit(1)
