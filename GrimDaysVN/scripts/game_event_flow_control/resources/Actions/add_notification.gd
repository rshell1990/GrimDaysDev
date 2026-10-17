extends GameAction
class_name GameActionAddNotification

## Text displayed when this operation runs.
@export_multiline var message: String


## Sends [code]completed[/code] notifications.
func execute() -> void:
    UIDirector.add_notification(message)
    completed.emit()
