extends Node
class_name ThreeDCameraPanner

## Shared fixed value for orginal delay.
const ORGINAL_DELAY = VNAnimationTimes.FAST

## Camera moved by this controller.
@export var camera: Camera3D
## Allowed horizontal camera movement around its starting position.
@export var horizontal_range: float
## Allowed vertical camera movement around its starting position.
@export var vertical_range: float

## Coordinates used for original position.
var original_position: Vector3


## When the node is ready, this function sets [code]original_position[/code] to
## [code]camera.global_position[/code].
func _ready() -> void:
    if camera == null:
        return
    original_position = camera.global_position


## Currently performs no work; this function is a placeholder for behavior supplied later or by a
## child script.
@warning_ignore("unused_parameter")
func _physics_process(delta: float) -> void:
    #cameraUpdate()
    pass


## Moves the camera according to the pointer position within the configured horizontal and vertical
## ranges.
func cameraUpdate():
    var pos = $"../Cover/Control".get_local_mouse_position()
    if pos.x >= -horizontal_range and pos.x < horizontal_range:
        camera.set_position(Vector3(pos.x, camera.position.y, camera.position.z))
