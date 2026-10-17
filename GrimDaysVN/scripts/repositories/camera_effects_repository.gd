extends Node
## Contains information about all the camera effects that can be called from the script,
## providing an easy way to reference them from other parts of the project.

## The resource that contains a list of the camera effects.
const CAMERA_EFFECTS = preload("res://GrimDaysVN/resources/camera_effects/all_camera_effects.tres")
var resource: CameraFXS = CAMERA_EFFECTS

## The dictionary accessed by other parts of the project.
var master: Dictionary


## Builds this repository’s lookup table from its assigned resources when the node is ready.
func _ready():
    if resource == null:
        return
    for effect in resource.directory:
        master[effect.called] = effect.resource
