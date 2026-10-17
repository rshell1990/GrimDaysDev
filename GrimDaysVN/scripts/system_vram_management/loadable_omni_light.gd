# Editor configuration for LoadableOmniLight.
@icon("res://GrimDays/assets/visuals/editor_icons/expanded-rays.svg")
extends OmniLight3D
class_name LoadableOmniLight


## Returns the light’s visibility, transform and lighting settings for later restoration.
func get_state() -> Dictionary:
    var state: Dictionary
    state = {
        "visible": visible,
        "global_position": global_position,
        "global_rotation": global_rotation,
        "light_energy": light_energy,
        "light_color": light_color,
        "light_angular_distance": light_angular_distance,
        "light_indirect_energy": light_indirect_energy,
        "light_volumetric_fog_energy": light_volumetric_fog_energy,
        "omni_range": omni_range,
        "omni_attenuation": omni_attenuation
    }
    return state


## Restores the saved visibility, transform and lighting settings to this light.
func restore_state(state: Dictionary) -> void:
    visible = state.visible
    global_position = state.global_position
    global_rotation = state.global_rotation
    light_energy = state.light_energy
    light_color = state.light_color
    light_angular_distance = state.light_angular_distance
    light_indirect_energy = state.light_indirect_energy
    light_volumetric_fog_energy = state.light_volumetric_fog_energy
    omni_range = state.omni_range
    omni_attenuation = state.omni_attenuation
