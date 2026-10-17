extends Node
## Movement helper that currently marks its owning character as stopped.
class_name CharacterSpritePlace

## Coordinates used for position.
var position: Vector3


## When the node is ready, this function sets [code]position[/code] to
## [code]get_parent().get_parent().global_position[/code].
func _ready():
    position = get_parent().get_parent().global_position


## Marks the owning character as stopped. This implementation does not apply a new position from the
## supplied data.
func execute(_data):
    var character = get_parent().get_parent()
    character.set_stopped()
