extends GameAction
class_name GameActionAdvanceTime


## Advances the game clock through [code]SystemAdministrators[/code].
func execute() -> void:
    SystemAdministrators.advance_time()
