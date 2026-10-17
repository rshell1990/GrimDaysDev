extends Node3D
class_name MapOperator
#region SIGNALS / VARS
## Location ID associated with this scene or map interaction.
@export var current_location: StringName
## Story event most recently supplied to this scene.
var found_event
## Information received from the previous scene during a scene change.
var given_data: Dictionary


#region MAIN
## When the node is ready, this function connects responses to
## [code]Dialogic.timeline_started[/code], [code]Dialogic.timeline_ended[/code],
## [code]VNSignalBus.event_found[/code].
func _ready() -> void:
    Dialogic.timeline_started.connect(on_timeline_start)
    Dialogic.timeline_ended.connect(on_timeline_ended)
    VNSignalBus.event_found.connect(on_event_found)


## Disables map processing while dialogue is running.
func on_timeline_start() -> void:
    process_mode = PROCESS_MODE_DISABLED


## Restores inherited map processing after dialogue ends.
func on_timeline_ended() -> void:
    process_mode = PROCESS_MODE_INHERIT


## Sets [code]found_event[/code] to [code]game_event[/code].
func on_event_found(game_event) -> void:
    found_event = game_event


#region SCENE MANAGEMENT
## Changes the current location through [code]SystemAdministrators[/code].
func init_scene() -> void:
    SystemAdministrators.set_location(current_location)
    SystemHelpers.print(self, ": Scene Init")


## Fades away the scene-transition cover so the new scene can be seen.
func start_scene() -> void:
    UIDirector.fade_flag_hide()
    SystemHelpers.print("Map Start")


## Stores the information supplied by the outgoing scene and announces that it was received.
func get_data_from_last_scene(data) -> void:
    #SystemHelpers.print(self, "receive's data.")
    given_data = data


## Returns the found story event for the scene that replaces this map.
func pass_data_to_next_scene() -> Dictionary:
    var data = {"found_event": found_event}
    return data
