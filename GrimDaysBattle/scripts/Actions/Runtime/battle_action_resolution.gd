extends RefCounted
## Represents the battle action resolution portion of deterministic battle action processing.
class_name BattleActionResolution

## Identifier copied from the request that produced this resolution.
var request_id: StringName
## Whether the resolver completed the action rather than rejecting it.
var success: bool
## Human-readable validation or execution failure; empty on success.
var error: String
## Authoritative combat events in the order they occurred.
var events: Array
## Units newly defeated while resolving this action.
var defeated: Array[BattleUnit]


## Appends one authoritative event to the resolution timeline.
func add_event(event: RefCounted) -> void:
    events.append(event)


## Returns a new array containing only events of [param type].
func get_events(type: int) -> Array:
    var matching: Array = []
    for event in events:
        if event.type == type:
            matching.append(event)
    return matching
