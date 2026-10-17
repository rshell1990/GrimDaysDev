extends GameAction
class_name GameActionTriggerEvent

## Event ID used to look up the story event to run.
@export var event_id: String


## Sends [code]VNSignalBus.event_found[/code], [code]completed[/code] notifications.
func execute() -> void:
    var event: GameEvent = SystemAdministrators.find_event_by_id(event_id)
    if not event.is_available():
        return
    VNSignalBus.event_found.emit(event)
    completed.emit()
