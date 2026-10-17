extends Node
class_name ShaderTextureLoader
## File or resource path used for path.
@export_file() var path: String
## Parent slider whose changes are displayed used by this node.
var parent: Sprite3D


## When the node enters the scene, this function changes a shader setting on [code]shader[/code];
## sets [code]parent[/code] to [code]get_parent()[/code].
func _enter_tree() -> void:
    var texture: CompressedTexture2D = ResourceLoader.load(
        path, "", ResourceLoader.CACHE_MODE_IGNORE
    )
    parent = get_parent()
    var shader: ShaderMaterial = parent.material_override
    shader.set_shader_parameter("albedo", texture)


## When the node leaves the scene, this function changes a shader setting on [code]shader[/code].
func _exit_tree() -> void:
    var shader: ShaderMaterial = parent.material_override
    shader.set_shader_parameter("albedo", null)
