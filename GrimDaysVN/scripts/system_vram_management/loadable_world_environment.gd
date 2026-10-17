# Editor configuration for LoadableWorldEnvironment.
@icon("res://GrimDays/assets/visuals/editor_icons/wireframe-globe.svg")
extends WorldEnvironment
class_name LoadableWorldEnvironment


## Returns the environment's glow settings, including brightness and threshold values, for later
## restoration.
func get_state() -> Dictionary:
    var state: Dictionary
    state = {
        "glow_enabled": environment.glow_enabled,
        "glow_intensity": environment.glow_intensity,
        "glow_bloom": environment.glow_bloom,
        "glow_hdr_threshold": environment.glow_hdr_threshold,
        "glow_hdr_scale": environment.glow_hdr_scale,
        "glow_hdr_luminance_cap": environment.glow_hdr_luminance_cap,
    }
    return state


## Applies saved values to this object’s display or resource settings, including shader settings
## when present.
func restore_state(state: Dictionary) -> void:
    environment.glow_enabled = state.glow_enabled
    environment.glow_intensity = state.glow_intensity
    environment.glow_bloom = state.glow_bloom
    environment.glow_hdr_threshold = state.glow_hdr_threshold
    environment.glow_hdr_scale = state.glow_hdr_scale
    environment.glow_hdr_luminance_cap = state.glow_hdr_luminance_cap
