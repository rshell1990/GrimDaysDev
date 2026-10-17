## Builds lookup entries for locations resources so other scripts can find them by ID.
class_name NavigationLocationsRepository
extends Node

## Source resource containing the entries this repository loads.
@export var resource: NavigationLocationsMaster

## Lookup table built from this repository’s source resources for other systems to query.
var master: Dictionary = {}


## When the node is ready, this function sets [code]master[location.id][/code] to
## [code]location[/code].
func _ready() -> void:
    if resource == null:
        return
    for locations in resource.all:
        for location in locations.all:
            master[location.id] = location
