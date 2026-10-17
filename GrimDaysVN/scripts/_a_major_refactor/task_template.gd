extends Task


## Currently performs no work; this function is a placeholder for behavior supplied later or by a
## child script.
func _init() -> void:
    pass


## Marks this task as ready when this task step is called.
func _prepare() -> void:
    goto_ready()


## Marks this task as completed when this task step is called.
func _complete() -> void:
    goto_completed()


## Marks this task as failed when this task step is called.
func _cancel() -> void:
    goto_failed()
