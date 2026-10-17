# Editor configuration for LoadablePanel.
@icon("res://GrimDays/assets/visuals/editor_icons/resize.svg")
extends Panel
class_name LoadablePanel


## Returns remembered values for visible, modulate, self modulate, global position, for saving or
## later restoration.
func get_state() -> Dictionary:
    var state: Dictionary
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
func restore_state(state: Dictionary) -> void:
    visible = state.visible
    modulate = state.modulate
    self_modulate = state.self_modulate
    global_position = state.global_position

    if not material:
        return
    if not material is ShaderMaterial:
        return

    var shader = material.shader
    var shader_uniforms: Array = shader.get_shader_uniform_list()
    for uniform_information in shader_uniforms:
        if not state.has(uniform_information.name):
            continue
        material.set_shader_parameter(uniform_information.name, state[uniform_information.name])
