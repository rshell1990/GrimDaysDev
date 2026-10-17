extends GameAction
class_name GameActionSetState

## Game mode to enter when this action runs.
@export var next_state: GameManagerStates.STATES


## Changes the game mode through [code]GameManager[/code]; sends [code]completed[/code]
## notifications.
func execute() -> void:
    GameManager.change_state(next_state)
    completed.emit()
