extends Node
class_name BaseSystemManager

## Tasks being preformed by the manager class.
var task_queue: TaskQueue


## Automatically initializes the task queue.
func _enter_tree() -> void:
    task_queue = TaskQueue.new(get_tree())
