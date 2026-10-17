extends GameAction
class_name GameActionAddQuest

## Quest definition to add when this action runs.
@export var new_quest: GameQuest


## Sends [code]completed[/code] notifications.
func execute() -> void:
    SystemAdministrators.add_quest(new_quest)
    completed.emit()
