## Builds lookup entries for history portraits resources so other scripts can find them by ID.
class_name HistoryPortraitsRepository
extends Node

## Source resource containing the entries this repository loads.
@export var resource: HistoryPortraits

## Lookup table built from this repository’s source resources for other systems to query.
var master: Dictionary = {}


## Builds this repository’s lookup table from its assigned resources when the node is ready.
func _ready() -> void:
    if resource == null:
        return
    for portrait in resource.all:
        master[portrait.id] = portrait
