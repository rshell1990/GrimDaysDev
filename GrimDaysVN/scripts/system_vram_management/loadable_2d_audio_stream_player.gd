# Editor configuration for LoadableAudioPlayer2D.
@icon("res://GrimDays/assets/visuals/editor_icons/ultrasound.svg")
extends AudioStreamPlayer2D
class_name LoadableAudioPlayer2D


## Returns playback, volume, pitch, pause and position values for later restoration.
func get_state() -> Dictionary:
    var state: Dictionary
    state = {
        "playing": playing,
        "volume_db": volume_db,
        "pitch_scale": pitch_scale,
        "stream_paused": stream_paused,
        "global_position": global_position
    }
    return state


## Restores playback, volume, pitch and pause values. The current implementation leaves
## global_position unchanged rather than reading it from the saved state.
func restore_state(state: Dictionary) -> void:
    playing = state.playing
    volume_db = state.volume_db
    pitch_scale = state.pitch_scale
    stream_paused = state.stream_paused
    global_position = global_position
