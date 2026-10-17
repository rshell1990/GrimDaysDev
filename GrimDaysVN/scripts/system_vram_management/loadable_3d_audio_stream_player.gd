# Editor configuration for LoadableAudioPlayer3D.
@icon("res://GrimDays/assets/visuals/editor_icons/acoustic-megaphone.svg")
extends AudioStreamPlayer3D
class_name LoadableAudioPlayer3D


## When the node is ready, this function connects responses to [code]owner.tree_exiting[/code].
func _ready() -> void:
    owner.tree_exiting.connect(fade_out)


## Smoothly changes [code]volume_db[/code] over time.
func fade_out() -> void:
    var tween = create_tween()
    tween.tween_property(self, "volume_db", -80.0, VNAnimationTimes.FAST)


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
