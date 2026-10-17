## Builds lookup entries for font resources so other scripts can find them by ID.
class_name FontRepository
extends Node

## Source resource containing the entries this repository loads.
@export var resource: GameFonts

## Lookup table built from this repository’s source resources for other systems to query.
var master: Dictionary = {}


## Builds this repository’s lookup table from its assigned resources when the node is ready.
func _ready() -> void:
    if resource == null:
        return
    for font in resource.all:
        master[font.id] = font
