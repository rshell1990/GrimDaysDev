extends Resource
## Top-level collection of story-event groups used by the event repository.
class_name GameEventsMaster

## Entries supplied by this resource collection for the systems that read it.
@export var all: Array[GameEvents]

## Events available by ID without being scheduled for navigation locations.
@export var called_events: Array[GameEvent]
