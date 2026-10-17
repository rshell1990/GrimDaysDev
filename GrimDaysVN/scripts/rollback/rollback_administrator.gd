extends Node
## Routes checkpoint and rollback commands to the rollback director.
class_name RollbackAdministrator
## Looks up the function to run for each supported command name.
var handle_command_by_type: Dictionary
## Helper responsible for carrying out this system’s requests.
var director: RollbackDirector


## Finds this system’s helper nodes, registers its command handlers and connects the notifications
## it responds to.
func _ready():
    director = get_child(0)
    VNSignalBus.clear_rollback.connect(on_clear_rollback)
    handle_command_by_type = {
        RollbackCommands.CHECKPOINT: on_checkpoint_command,
        RollbackCommands.ROLLBACK: on_rollback_command,
    }


## Uses the command type to select a registered handler and forwards the supplied arguments to that
## handler.
func command(arg) -> void:
    if arg is Dictionary:
        handle_command_by_type[arg.type].call(arg.info)
    else:
        handle_command_by_type[arg].call()


## Asks the rollback director to load the last checkpoint.
func on_rollback_command() -> void:
    director.load_last_checkpoint()


## Asks the rollback director to make a checkpoint.
func on_checkpoint_command() -> void:
    director.make_checkpoint()


## Asks the rollback director to clear remembered rollback data.
func on_clear_rollback() -> void:
    director.clear_rollback()


## Passes the current state to the rollback system to remember for a later restore.
func set_current_rollback_data(new_data: Dictionary) -> void:
    director.set_current_rollback_data(new_data)


## Returns the state currently remembered by the rollback system.
func get_current_rollback_data() -> Dictionary:
    return director.get_current_rollback_data()
