extends Node
class_name SpineAnimationsRepository
## Master list of animations that the spine sprites have. It takes a resource
## list of animations and then sorts them into a dictionary that can be
## refrenced to get information about the animation throughout the project.

## The resource file containing information about the animations.

## Source resource containing the entries this repository loads.
@export var resource: MasterAnimationDictionary
## Lookup table for default expression; keys select the corresponding stored values.
@export var default_expression: Dictionary[String, Array]

## The dictionary to be accessed by other parts of the project.
var master: Dictionary


## Builds this repository’s lookup table from its assigned resources when the node is ready.
func _ready():
    if resource == null:
        return
    for id in resource.directory:
        var character_animations = resource.directory[id]
        master[id] = {}
        for animation in character_animations.animations:
            master[id][animation.called] = animation
            if animation.called != animation.animation_name:
                master[id][animation.animation_name] = animation
