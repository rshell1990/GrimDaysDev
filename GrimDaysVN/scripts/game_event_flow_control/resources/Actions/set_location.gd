extends GameAction
class_name GameActionSetLocation

## Location ID to set when this action runs.
@export var new_location: StringName


## Changes the current location through [code]SystemAdministrators[/code]; sends
## [code]completed[/code] notifications.
func execute() -> void:
    SystemAdministrators.set_location(new_location)
    completed.emit()
