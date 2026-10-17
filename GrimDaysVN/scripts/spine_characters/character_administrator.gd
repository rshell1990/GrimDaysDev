## Routes character placement, movement, expression and skin commands.
class_name CharacterSpriteAdministrator
extends Node

## Looks up the function to run for each supported command name.
var handle_command_by_type: Dictionary
## Helper responsible for carrying out this system’s requests.
var director: CharacterSpriteDirector


## Registers a named character display layer with the character system.
func add_depths(depth_name: String, sent_depth: DepthOperator) -> void:
    director.add_depths(depth_name, sent_depth)


## Removes a named character display layer from the character system's lookup.
func remove_depths(depth_name: String) -> void:
    director.remove_depths(depth_name)


## Converts command arguments into a dictionary and requests a character transfer between display
## layers.
func on_transfer_command(args: PackedStringArray) -> void:
    var data: Dictionary = SystemHelpers.args_to_dict(args)
    director.relay_transfer(data)


## Converts command arguments and waits for the requested character to leave.
func on_leave_command(args: PackedStringArray) -> void:
    var data: Dictionary = SystemHelpers.args_to_dict(args)
    await director.relay_leave(data)


## Converts command arguments and requests character movement.
func on_move_command(args: PackedStringArray) -> void:
    var data: Dictionary = SystemHelpers.args_to_dict(args)
    director.relay_movement(data)


## Converts command arguments and requests a character to be added.
func on_add_command(args: PackedStringArray) -> void:
    var data: Dictionary = SystemHelpers.args_to_dict(args)
    director.relay_add(data)


## Converts command arguments and requests a change in the character's facing direction.
func on_flip_command(args: PackedStringArray) -> void:
    var data: Dictionary = SystemHelpers.args_to_dict(args)
    director.relay_flip(data)


## Converts command arguments and requests a character expression change.
func on_expression_command(args) -> void:
    var data: Dictionary = SystemHelpers.args_to_dict(args)
    #data.animations = data.animations.split(Basics.COMMA)

    director.relay_expression(data)


## Requests that characters leave the registered display layers.
func clear_depths() -> void:
    director.clear_depths()


## Converts command arguments and requests a character skin change.
func on_skin_command(args) -> void:
    var data: Dictionary = SystemHelpers.args_to_dict(args)
    director.relay_skin(data)


## Asks the character director to find display layers in the replacement world scene.
func on_world_swapped(_args) -> void:
    #SystemHelpers.print("Layers Swap - To Director")
    director._reconnect_depths()


## Sets [code]Dialogic.paused[/code] to true. It pauses for
## [code]Dialogic.Animations.finished[/code],
## [code]handle_command_by_type[parsed_arg].call(final_args)[/code] before continuing.
func command(arg: Variant) -> void:
    CustomLogger.warn(
        self,
        self.command,
        "A character spine sprite command has been received, so will pause Dialogic.",
        CustomLogger.LEVEL.VERBOSE
    )
    Dialogic.paused = true
    var final_args = arg.slice(1, arg.size())
    var parsed_arg = arg[Basics.FIRST].to_lower()
    if Dialogic.Animations.is_animating():
        await Dialogic.Animations.finished
    await handle_command_by_type[parsed_arg].call(final_args)


## Forwards the first command argument as saved character data to the director.
func on_load_command(args) -> void:
    director._on_load(args[Basics.FIRST])


## Finds this system’s helper nodes, registers its command handlers and connects the notifications
## it responds to.
func _ready():
    director = get_child(0)
    handle_command_by_type = {
        CharacterCommands.TRANSFER: on_transfer_command,
        CharacterCommands.ADD: on_add_command,
        CharacterCommands.EXPRESSION: on_expression_command,
        CharacterCommands.SKIN: on_skin_command,
        CharacterCommands.FLIP: on_flip_command,
        CharacterCommands.MOVE: on_move_command,
        CharacterCommands.LEAVE: on_leave_command,
        CharacterCommands.LOAD_CHECKPOINT: on_load_command,
        WorldCommands.WORLD_SWAPPED: on_world_swapped,
    }
