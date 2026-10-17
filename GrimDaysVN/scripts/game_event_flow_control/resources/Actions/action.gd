extends Resource
## Base class for game actions.
class_name GameAction
## Notification for completed.
signal completed


## To override.
func execute() -> void:
    pass
