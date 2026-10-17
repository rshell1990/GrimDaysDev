extends GameAction
class_name GameActionSetWorldStage

## World-stage number to apply to story progress when this action runs.
@export var new_stage: int


## Updates story progress through [code]GameManager[/code]; sends [code]completed[/code]
## notifications.
func execute() -> void:
    GameManager.update_world_stage(new_stage)
    completed.emit()
