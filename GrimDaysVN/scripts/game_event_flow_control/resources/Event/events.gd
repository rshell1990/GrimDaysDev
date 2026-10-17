# Editor configuration for GameEvents.
@icon("res://GrimDays/assets/visuals/editor_icons/greenhouse.svg")
extends Resource
## Collection of story-event definitions.
class_name GameEvents

## Where the event takes place.
@export var location: StringName
## Story-event definitions belonging to this event collection.
@export var all: Array[GameEvent]
