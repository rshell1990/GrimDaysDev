## Exercises portrait scene visuals, event handoff and signal lifecycle without writing saves.
extends Node

const ROOM = preload("res://GrimDaysVN/resources/events/1_0010_livingroom.tres")

var completed_checks: int = 0
var received_data: int = 0
var initialized_scene: PortraitedSceneOperator


func _ready() -> void:
    get_tree().create_timer(15.0).timeout.connect(_on_timeout)
    _run.call_deferred()


func _run() -> void:
    var operator := PortraitedSceneOperator.new()
    operator.background_holder = Node3D.new()
    operator.foreground_holder = Node3D.new()
    operator.add_child(operator.background_holder)
    operator.add_child(operator.foreground_holder)
    add_child(operator)
    _check_data(operator)
    _check_visuals(operator)
    _check_connections(operator)
    await _check_start(operator)
    assert(completed_checks == 4, "A portrait scene check did not finish.")
    operator.queue_free()
    await get_tree().process_frame
    print("PORTRAITED_SCENE_OPERATOR_SMOKE_TEST: PASS") # lint:ignore debug-print -- Required test/CLI output.
    get_tree().quit()


func _check_data(operator: PortraitedSceneOperator) -> void:
    operator.data_given.connect(func() -> void: received_data += 1)
    var data: Dictionary = {"found_event": ROOM}
    operator.get_data_from_last_scene(data)
    data.clear()
    assert(operator.given_data.found_event == ROOM)
    assert(operator.pass_data_to_next_scene().found_event == ROOM)
    assert(received_data == 1)
    operator.get_data_from_last_scene({"found_event": "invalid"})
    assert(operator.found_event == ROOM and received_data == 1)
    operator.get_data_from_last_scene({})
    assert(operator.found_event == null and operator.given_data.is_empty())
    operator.on_event_found(ROOM)
    operator.on_event_found(null)
    assert(operator.pass_data_to_next_scene().found_event == ROOM)
    completed_checks += 1


func _check_visuals(operator: PortraitedSceneOperator) -> void:
    var repository: NavigationLocationsRepository = Repositories.get_repository(RepositoryTypes.LOCATIONS)
    var original: Dictionary = repository.master.duplicate()
    var director: NavigationDirector = SystemAdministrators.navigation_admin.director
    var original_location: StringName = director.location
    repository.master.clear()
    director.location = &"PortraitSmokeTest"
    var template := Node3D.new()
    var scene := PackedScene.new()
    assert(scene.pack(template) == OK)
    template.free()
    var location := NavigationLocation.new()
    location.id = director.location
    location.background = scene
    location.foreground_objects = [scene, scene]
    repository.master[location.id] = location
    operator.intialized_scene.connect(func(value: PortraitedSceneOperator) -> void: initialized_scene = value)
    operator.init_scene()
    assert(initialized_scene == operator and operator.init)
    operator.on_location_change()
    assert(operator.background_holder.get_child_count() == 1)
    assert(operator.foreground_holder.get_child_count() == 2)
    var background: Node = operator.background_holder.get_child(0)
    director.location = &"MissingPortraitLocation"
    operator.on_location_change()
    assert(operator.background_holder.get_child(0) == background)
    director.location = location.id
    location.background = null
    operator.on_location_change()
    assert(operator.background_holder.get_child(0) == background)
    location.background = scene
    location.foreground_objects = [null]
    operator.on_location_change()
    assert(operator.background_holder.get_child(0) == background)
    location.foreground_objects = []
    operator.on_timeline_end()
    operator.on_location_change()
    assert(operator.background_holder.get_child(0) == background)
    operator.on_timeline_start()
    operator.on_location_change()
    assert(operator.background_holder.get_child(0) != background)
    location.id = &"PrimeMap"
    operator.on_location_change()
    assert(operator.background_holder.get_child_count() == 0)
    assert(operator.foreground_holder.get_child_count() == 0)
    var holder: Node = operator.background_holder
    operator.background_holder = null
    operator.on_location_change()
    operator.background_holder = holder
    director.location = original_location
    repository.master.clear()
    repository.master.merge(original)
    completed_checks += 1


func _check_connections(operator: PortraitedSceneOperator) -> void:
    remove_child(operator)
    assert(not VNSignalBus.event_found.is_connected(operator.on_event_found))
    assert(not VNSignalBus.location_changed.is_connected(operator.on_location_change))
    assert(not Dialogic.timeline_started.is_connected(operator.on_timeline_start))
    assert(not Dialogic.timeline_ended.is_connected(operator.on_timeline_end))
    add_child(operator)
    assert(VNSignalBus.event_found.is_connected(operator.on_event_found))
    assert(VNSignalBus.location_changed.is_connected(operator.on_location_change))
    assert(Dialogic.timeline_started.is_connected(operator.on_timeline_start))
    assert(Dialogic.timeline_ended.is_connected(operator.on_timeline_end))
    completed_checks += 1


func _check_start(operator: PortraitedSceneOperator) -> void:
    var original_restoring: bool = SaveAndLoadSystemManager.restoring_data
    operator.get_data_from_last_scene({"found_event": ROOM})
    SaveAndLoadSystemManager.restoring_data = true
    operator.start_scene()
    assert(Dialogic.current_timeline == null)
    SaveAndLoadSystemManager.restoring_data = false
    operator.on_event_found(GameEventSequence.new())
    operator.start_scene()
    assert(Dialogic.current_timeline == null)
    var original_state: GameManagerStates.STATES = GameManager.state
    # Set the state field only to isolate the operator from state-entry scene swaps.
    GameManager.state = GameManagerStates.STATES.TimeChanging
    operator.on_event_found(ROOM)
    operator.start_scene()
    operator.on_event_found(GameEventSequence.new())
    await get_tree().create_timer(VNAnimationTimes.SLOW + 0.1).timeout
    assert(Dialogic.current_timeline == null, "A superseded event must not start after the delay.")
    GameManager.state = original_state
    operator.get_data_from_last_scene({"found_event": ROOM})
    operator.start_scene()
    await get_tree().create_timer(0.5).timeout
    assert(Dialogic.current_timeline == ROOM.timeline)
    assert(not operator.timeline_ended_after_init)
    GameManager.on_loading_sequence_start()
    await Dialogic.clear()
    await get_tree().create_timer(0.5).timeout
    SaveAndLoadSystemManager.restoring_data = original_restoring
    completed_checks += 1


func _on_timeout() -> void:
    push_error("PORTRAITED_SCENE_OPERATOR_SMOKE_TEST: timed out.")
    get_tree().quit(1)
