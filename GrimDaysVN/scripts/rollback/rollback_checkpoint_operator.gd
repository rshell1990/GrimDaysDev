extends Node
## Forwards checkpoint creation and restoration to its operation helpers.
class_name CheckpointOperator

## Notification for checkpoint loaded. Supplies [code]args[/code] to connected functions.
signal checkpoint_loaded(args)


## Adds [code]checkpoint_load_operation[/code] as a child node; schedules
## [code]checkpoint_load_operation[/code] for deletion. It pauses for
## [code]checkpoint_load_operation.finished[/code] before continuing.
func load_last_checkpoint():
    var checkpoint_load_operation = LoadCheckpointOperation.new()
    add_child(checkpoint_load_operation)
    checkpoint_load_operation.execute()
    await checkpoint_load_operation.finished
    checkpoint_load_operation.queue_free()


## Requests a rollback checkpoint through [code]SaveAndLoadSystemManager[/code].
func make_checkpoint():
    SaveAndLoadSystemManager.save_checkpoint()
