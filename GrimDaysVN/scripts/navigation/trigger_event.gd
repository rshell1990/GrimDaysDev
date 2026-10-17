extends Node
class_name InteractableCustomActionEventTrigger

## Event ID used to look up the story event to run.
@export var event_id: String


## Sends [code]VNSignalBus.event_found[/code] notifications.
func execute() -> void:
    CustomLogger.confirm(self, execute, "Triggering event: " + event_id, 3)
    var event = SystemAdministrators.find_event_by_id(event_id)
    VNSignalBus.event_found.emit(event)
