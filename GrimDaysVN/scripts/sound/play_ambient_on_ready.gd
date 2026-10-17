extends Node3D
class_name NavigationLocationWithAmbiance
## Lookup table for ambient track id; keys select the corresponding stored values.
@export var ambient_track_id: Dictionary[TimeAdministrator.TIMES, String] = {
    TimeAdministrator.TIMES.Dawn: "",
    TimeAdministrator.TIMES.Morning: "",
    TimeAdministrator.TIMES.Afternoon: "",
    TimeAdministrator.TIMES.Evening: "",
    TimeAdministrator.TIMES.Night: "",
    TimeAdministrator.TIMES.Bedtime: ""
}

## ID of the ambience track currently selected for playback.
var currently_playing: String


## When the node is ready, this function connects responses to
## [code]VNSignalBus.location_changed[/code], [code]VNSignalBus.time_passed[/code]. It pauses for
## [code]get_tree().create_timer(1.0).timeout[/code] before continuing.
func _ready() -> void:
    if ambient_track_id[SystemAdministrators.current_time()].is_empty():
        return
    play_ambient_sound(ambient_track_id[SystemAdministrators.current_time()])
    await get_tree().create_timer(1.0).timeout
    VNSignalBus.location_changed.connect(on_location_change)
    VNSignalBus.time_passed.connect(on_time_passed)


## Plays background ambience through [code]SoundManager[/code]; sets [code]currently_playing[/code]
## to [code]id[/code].
func play_ambient_sound(id: String) -> void:
    currently_playing = id
    SoundManager.play_ambient_sound(id, 1.0, 1.0, "Effect Ambient")


## Switches ambience only when the old and new times of day use different tracks.
func on_time_passed(old_time: TimeAdministrator.TIMES, new_time: TimeAdministrator.TIMES) -> void:
    var last_played = ambient_track_id[old_time]
    var to_be_played = ambient_track_id[new_time]
    if last_played == to_be_played:
        return
    SoundManager.stop_ambient_sound(last_played, 0.05)
    play_ambient_sound(to_be_played)


## Stops this location's current ambience, if any, when the location changes.
func on_location_change(_new_location) -> void:
    if currently_playing.is_empty():
        return
    CustomLogger.confirm(
        self,
        on_location_change,
        "Location changed, stopping ambient track: " + currently_playing,
        CustomLogger.LEVEL.VERY_VERBOSE
    )
    SoundManager.stop_ambient_sound(currently_playing, 0.05)
