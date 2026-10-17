extends SubViewport
class_name ShadedSprite2DSubViewport

## Stored path to file used by this script’s update and input handling.
@export_file() var path_to_file: String
## Image displayed for this resource entry.
var texture


## When the node enters the scene, this function updates [code]texture[/code] using
## [code]ResourceLoader.load[/code].
func _enter_tree() -> void:
    var type_hint: String = ""
    var cache_mode := ResourceLoader.CACHE_MODE_IGNORE_DEEP
    texture = ResourceLoader.load(path_to_file, type_hint, cache_mode)


## When the node leaves the scene, this function sets [code]texture[/code] to null.
func _exit_tree() -> void:
    texture = null


## When the node is ready, this function changes a shader setting on [code]child_material[/code].
func _ready() -> void:
    var child: Sprite2D = get_child(0)
    var child_material: ShaderMaterial = child.material
    child_material.set_shader_parameter("screen", texture)
