extends Node
class_name CharacterModelRepository

## The resource file containing information about layred characters.
@export var resource: LayeredCharacterModels

## The dictionary to be accessed by other parts of the project.
var master: Dictionary


## Copies each model entry from the assigned resource into the repository lookup; does nothing if no
## resource is assigned.
func _ready() -> void:
    if resource == null:
        return
    for entry in resource.all.keys():
        master.set(entry, resource.all[entry])
