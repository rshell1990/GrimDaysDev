# Editor configuration for distribute_over_bezier.
@tool
extends Control

## Scene object used for start.
@export var start: Control
## Scene object used for middle.
@export var middle: Control
## Scene object used for end.
@export var end: Control
## List of textures used by this script.
@export var textures: Array[TextureRect]


## Places the configured textures along the curve when the node is ready.
func _ready() -> void:
    set_positions()


## Spreads the textures from start to end along the curve, using their order in the texture list.
func set_positions() -> void:
    var max_textures: float = (textures.size() - 1) * 1.0
    for x in range(0, max_textures + 1):
        textures[x].position = _get_point_on_bezier(x / max_textures)


## Returns a point on the curve by interpolating between the start, middle and end controls at the
## supplied fraction.
func _get_point_on_bezier(percentage: float) -> Vector2:
    var start_point: Vector2 = start.position.lerp(middle.position, percentage)
    var end_point: Vector2 = middle.position.lerp(end.position, percentage)
    var bezier_point: Vector2 = start_point.lerp(end_point, percentage)

    return bezier_point
