# Editor configuration for LoadableSprite3D.
@icon("res://GrimDays/assets/visuals/at-icons/node3d/image.svg")
extends Sprite3D
class_name LoadableSprite3D
## File or resource path used for path.
@export_file() var path: String


## Loads the configured texture when this node enters the scene, without reusing the deep resource
## cache.
func _enter_tree() -> void:
    if path.is_empty():
        return
    texture = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)


## Releases the loaded texture when this node leaves the scene and a load path is configured.
func _exit_tree() -> void:
    if path.is_empty():
        return
    texture = null


## Returns remembered values for visible, modulate, global position, global rotation, for saving or
## later restoration.
func get_state() -> Dictionary:
    var state: Dictionary
    state = {
        "visible": visible,
        "modulate": modulate,
        "global_position": global_position,
        "global_rotation": global_rotation,
    }
    if not material_override:
        return state
    if not material_override is ShaderMaterial:
        return state
    var material: ShaderMaterial = material_override
    var shader: Shader = material.shader
    var shader_uniforms: Array = shader.get_shader_uniform_list()
    for uniform_information in shader_uniforms:
        var parameter_value: Variant = material.get_shader_parameter(uniform_information.name)
        if typeof(parameter_value) == TYPE_OBJECT:
            continue
        state.set(uniform_information.name, parameter_value)

    return state


## Applies saved values to this object’s display or resource settings, including shader settings
## when present.
func restore_state(state: Dictionary) -> void:
    visible = state.visible
    modulate = state.modulate
    global_position = state.global_position
    global_rotation = state.global_rotation
    if not material_override:
        return
    if not material_override is ShaderMaterial:
        return
    var material: ShaderMaterial = material_override
    var shader: Shader = material.shader
    var shader_uniforms: Array = shader.get_shader_uniform_list()
    for uniform_information in shader_uniforms:
        if not state.has(uniform_information.name):
            continue
        var parameter = state[uniform_information.name]
        material.set_shader_parameter(uniform_information.name, parameter)
