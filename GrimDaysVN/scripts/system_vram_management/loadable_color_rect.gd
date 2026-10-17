# Editor configuration for LoadableColorRect.
@icon("res://GrimDays/assets/visuals/editor_icons/paint-bucket.svg")
extends ColorRect
class_name LoadableColorRect

## Lookup table for state; keys select the corresponding stored values.
var state: Dictionary


## Collects this object’s current visible, modulate, self modulate, global position into a
## dictionary for saving or restoration.
func get_state() -> Dictionary:
    state = {
        "visible": visible,
        "modulate": modulate,
        "self_modulate": self_modulate,
        "global_position": global_position,
    }
    if not material:
        return state
    if not material is ShaderMaterial:
        return state

    var shader = material.shader
    var shader_uniforms: Array = shader.get_shader_uniform_list()
    for uniform_information in shader_uniforms:
        var parameter_value: Variant = material.get_shader_parameter(uniform_information.name)
        if typeof(parameter_value) == TYPE_OBJECT:
            continue
        state.set(uniform_information.name, parameter_value)

    return state


## Applies saved values to this object’s display or resource settings, including shader settings
## when present.
func restore_state(old_state: Dictionary) -> void:
    visible = old_state.visible
    modulate = old_state.modulate
    self_modulate = old_state.self_modulate
    global_position = old_state.global_position

    if not material:
        return
    if not material is ShaderMaterial:
        return

    var shader = material.shader
    var shader_uniforms: Array = shader.get_shader_uniform_list()
    for uniform_information in shader_uniforms:
        if not old_state.has(uniform_information.name):
            continue
        material.set_shader_parameter(uniform_information.name, old_state[uniform_information.name])
