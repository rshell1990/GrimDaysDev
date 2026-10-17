extends GameAction
class_name GameActionChangeTime

## Time-of-day choice to apply when this action runs.
@export var new_time: TimeAdministrator.TIMES


## Sets the game clock through [code]SystemAdministrators[/code].
func execute() -> void:
    SystemAdministrators.jump_to_time(new_time)
