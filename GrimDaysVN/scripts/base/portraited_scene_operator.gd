## Coordinates a story scene's background, foreground and event data during scene changes.
#region PORTRAITED SCENE
##
##
##
class_name PortraitedSceneOperator extends Node3D
#endregion

#region SIGNALS
## Retains the existing signal name for scene compatibility.
signal intialized_scene(scene: PortraitedSceneOperator)
## Notification for data given.
signal data_given
#endregion

#region EXPORTS
## Scene object used for background holder.
@export var background_holder: Node
## Scene object used for foreground holder.
@export var foreground_holder: Node
#endregion

## Whether init is currently enabled or true.
var init: bool = false
## Whether timeline ended after init is currently enabled or true.
var timeline_ended_after_init: bool = false

#region VARIABLES
## Information received from the previous scene during a scene change.
var given_data: Dictionary
## Story event most recently supplied to this scene.
var found_event: GameEvent
#endregion


#region HOUSEKEEPING
## When the node enters the scene, this function connects responses to
## [code]VNSignalBus.event_found[/code], [code]VNSignalBus.location_changed[/code],
## [code]Dialogic.timeline_ended[/code].
func _enter_tree() -> void:
    VNSignalBus.event_found.connect(on_event_found)
    VNSignalBus.location_changed.connect(on_location_change)
    Dialogic.timeline_started.connect(on_timeline_start)
    Dialogic.timeline_ended.connect(on_timeline_end)


func _exit_tree() -> void:
    VNSignalBus.event_found.disconnect(on_event_found)
    VNSignalBus.location_changed.disconnect(on_location_change)
    Dialogic.timeline_started.disconnect(on_timeline_start)
    Dialogic.timeline_ended.disconnect(on_timeline_end)


#endregion


#region MANAGEMENT
## Changes the mouse pointer image; sets [code]init[/code] to true; sends
## [code]intialized_scene[/code] notifications.
func init_scene() -> void:
    UIDirector.hide_navigation()
    Input.set_custom_mouse_cursor(null)
    timeline_ended_after_init = false
    on_location_change()
    init = true
    intialized_scene.emit(self)


func on_timeline_start() -> void:
    timeline_ended_after_init = false


## Sets [code]timeline_ended_after_init[/code] to true.
func on_timeline_end() -> void:
    if not init:
        return
    timeline_ended_after_init = true


## Replaces location visuals only after validating the holders and scene resources.
func on_location_change(_name: String = "") -> void:
    if timeline_ended_after_init:
        return
    if not is_instance_valid(background_holder) or not is_instance_valid(foreground_holder):
        CustomLogger.warn(
            self, on_location_change, "Location visual holders are missing.", CustomLogger.LEVEL.IMPORTANT
        )
        return

    var location_id: StringName = SystemAdministrators.current_location()
    var location: NavigationLocation = Repositories.get_info(
        RepositoryTypes.LOCATIONS, location_id
    )
    if location == null:
        CustomLogger.warn(
            self, on_location_change, "No location resource for: %s" % location_id, CustomLogger.LEVEL.IMPORTANT
        )
        return
    if location.id == &"PrimeMap":
        _clear_location_visuals()
        return
    if location.background == null or not location.background.can_instantiate():
        CustomLogger.warn(
            self, on_location_change, "No usable background for: %s" % location_id, CustomLogger.LEVEL.IMPORTANT
        )
        return
    var foreground_objects: Array[PackedScene] = location.foreground_objects
    for object: PackedScene in foreground_objects:
        if object == null or not object.can_instantiate():
            CustomLogger.warn(
                self, on_location_change, "Invalid foreground for: %s" % location_id, CustomLogger.LEVEL.IMPORTANT
            )
            return
    var new_background: Node = location.background.instantiate()
    _clear_location_visuals()
    background_holder.add_child(new_background)
    CustomLogger.hint(
        self,
        self.on_location_change,
        (
            "Changing background to:"
            + str(new_background)
            + " and adding:\n"
            + str(foreground_objects)
            + " to the foreground."
        ),
        CustomLogger.LEVEL.MILD
    )
    for object in foreground_objects:
        foreground_holder.add_child(object.instantiate())


func _clear_location_visuals() -> void:
    for holder: Node in [background_holder, foreground_holder]:
        for child: Node in holder.get_children():
            holder.remove_child(child)
            child.queue_free()


## Sets [code]found_event[/code] to [code]game_event[/code].
func on_event_found(game_event: GameEvent) -> void:
    if game_event == null:
        CustomLogger.warn(self, on_event_found, "Received an empty event.", CustomLogger.LEVEL.IMPORTANT)
        return
    CustomLogger.confirm(self, self.on_event_found, "Event found: " + game_event.id, CustomLogger.LEVEL.MILD)
    found_event = game_event


## Starts the selected dialogue timeline. It pauses for
## [code]get_tree().create_timer(VNAnimationTimes.SLOW).timeout[/code] before continuing.
func start_scene() -> void:
    CustomLogger.hint(self, self.start_scene, "Portraited Scene starting...", CustomLogger.LEVEL.MILD)
    UIDirector.fade_flag_hide()
    if found_event == null:
        found_event = GameManager.current_event
    if SaveAndLoadSystemManager.restoring_data or found_event == null:
        return
    var event_to_start: GameEvent = found_event
    if event_to_start.timeline == null:
        CustomLogger.warn(
            self, start_scene, "Event has no timeline: %s" % event_to_start.id, CustomLogger.LEVEL.IMPORTANT
        )
        return
    CustomLogger.confirm(
        self,
        self.start_scene,
        "Starting timeline:[i]" + str(event_to_start.timeline) + "[/i]",
        CustomLogger.LEVEL.MILD
    )
    if GameManager.state == GameManagerStates.STATES.TimeChanging:
        await get_tree().create_timer(VNAnimationTimes.SLOW).timeout
        if not is_inside_tree() or found_event != event_to_start or SaveAndLoadSystemManager.restoring_data:
            return
    Dialogic.start(event_to_start.timeline)


## Stores the information supplied by the outgoing scene and announces that it was received.
func get_data_from_last_scene(data: Dictionary) -> void:
    CustomLogger.confirm(self, self.get_data_from_last_scene, "received data.", CustomLogger.LEVEL.MILD)
    var incoming_event: Variant = data.get("found_event")
    if incoming_event != null and not incoming_event is GameEvent:
        CustomLogger.warn(
            self, get_data_from_last_scene, "Received invalid event data.", CustomLogger.LEVEL.IMPORTANT
        )
        return
    given_data = data.duplicate()
    found_event = incoming_event
    data_given.emit()


## Returns the found event so the replacement scene can continue handling it.
func pass_data_to_next_scene() -> Dictionary:
    var data: Dictionary = {"found_event": found_event}
    return data
