## Routes camera commands to movement, effect and restore helpers.
class_name CameraAdministrator
extends Node
## Looks up the function to run for each supported command name.
var handle_command_by_type: Dictionary
## Helper responsible for carrying out this system’s requests.
var director: CameraDirector


## Converts command arguments into named values and forwards the camera movement request.
func on_move(args) -> void:
    var data: Dictionary = SystemHelpers.args_to_dict(args)
    director.relay_move(data)


## Converts command arguments into named values and forwards the camera-effect request.
func on_effect(args) -> void:
    var data: Dictionary = SystemHelpers.args_to_dict(args)
    director.relay_effect(data)


## Forwards saved camera data to the camera director.
func on_load(args) -> void:
    director.relay_load(args[1])


## Asks the camera director to reconnect the new scene's cameras.
func on_swap(_args) -> void:
    director.reconnect_cameras()


## Waits for any current dialogue animation, then runs the handler selected by the command name.
func command(args: Variant) -> void:
    var type = args[Basics.FIRST].split(Basics.COLON)[Basics.FIRST].to_lower()
    if Dialogic.Animations.is_animating():
        await Dialogic.Animations.finished
    handle_command_by_type[type].call(args)


## Finds this system’s helper nodes, registers its command handlers and connects the notifications
## it responds to.
func _ready():
    director = get_child(0)
    handle_command_by_type = {
        CameraCommands.MOVE: on_move,
        CameraCommands.FX: on_effect,
        SystemHeadquarters.LOADING: on_load,
        WorldCommands.WORLD_SWAPPED: on_swap,
    }
