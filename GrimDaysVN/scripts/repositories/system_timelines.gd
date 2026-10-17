## Builds lookup entries for system timelines resources so other scripts can find them by ID.
class_name DialogicTimelinesRepository
extends Node

## Source resource containing the entries this repository loads.
@export var resource: DialogicTimelineReferences

## Lookup table built from this repository’s source resources for other systems to query.
var master: Dictionary = {}


## When the node is ready, this function sets [code]master[entry.get_timeline_id()][/code] to
## [code]entry.timeline[/code].
func _ready() -> void:
    if resource == null:
        return
    for entry in resource.all:
        master[entry.get_timeline_id()] = entry.timeline
