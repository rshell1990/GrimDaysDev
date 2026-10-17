extends Node
## Older helper that reads a rollback checkpoint and restores its saved data.
class_name LoadCheckpointOperation
## Notification for finished.
signal finished

## Saved state shared by calls to this checkpoint-loading helper.
static var loaded_state: Dictionary = {}


## Requests restoration of a rollback checkpoint through [code]SaveAndLoadSystemManager[/code];
## sends [code]finished[/code] notifications. It pauses for
## [code]SaveAndLoadSystemManager.task_queue.queue_finished[/code] before continuing.
func execute() -> void:
    SaveAndLoadSystemManager.load_checkpoint()
    await SaveAndLoadSystemManager.task_queue.queue_finished
    finished.emit()
