extends GameAction
class_name GameActionAdvanceToTime

## Time-of-day choice to advance the game clock to when this action runs.
@export var time: TimeAdministrator.TIMES


## Advances the game clock to the requested time through [code]SystemAdministrators[/code].
func execute() -> void:
    if time == SystemAdministrators.current_time():
        return
    SystemAdministrators.advance_to_time(time)
