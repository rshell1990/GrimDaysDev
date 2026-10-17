extends Node
class_name EventAdministrator
## Helper that chooses and starts available story events.
var event_director


## When the node is ready, this function connects responses to [code]VNSignalBus.event_found[/code];
## sets [code]event_director[/code] to [code]get_child(0)[/code].
func _ready() -> void:
    event_director = get_child(0)
    VNSignalBus.event_found.connect(on_event_found)


## Returns [code]event_director.check_for_event(target_location,
## SystemAdministrators.time_admin.current_day_id(), SystemAdministrators.current_time())[/code].
func check_for_event(target_location) -> GameEvent:
    return event_director.check_for_event(
        target_location,
        SystemAdministrators.time_admin.current_day_id(),
        SystemAdministrators.current_time()
    )


## Forwards the found story event to the event director to start it.
func on_event_found(game_event: GameEvent) -> void:
    CustomLogger.confirm(
        self, self.on_event_found, "Event found: " + game_event.id, CustomLogger.LEVEL.MILD
    )
    event_director.on_event_found(game_event)
