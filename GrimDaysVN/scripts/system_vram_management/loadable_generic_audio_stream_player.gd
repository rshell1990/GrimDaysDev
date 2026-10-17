# Editor configuration for LoadableGenericAudioPlayer.
@icon("res://GrimDays/assets/visuals/editor_icons/megaphone.svg")
extends AudioStreamPlayer
class_name LoadableGenericAudioPlayer


## Returns remembered values for playing, volume db, pitch scale, stream paused, playback position,
## for saving or later restoration.
func get_state() -> Dictionary:
    var state: Dictionary
    state = {
        "playing": playing,
        "volume_db": volume_db,
        "pitch_scale": pitch_scale,
        "stream_paused": stream_paused,
        "playback_position": get_playback_position()
    }
    return state


## Restores volume, pitch and pause settings, and resumes at the saved playback position when the
## saved state was playing.
func restore_state(state: Dictionary) -> void:
    volume_db = state.volume_db
    pitch_scale = state.pitch_scale
    if state.playing:
        play(state.playback_position)
    stream_paused = state.stream_paused
