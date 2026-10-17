extends Node
## Routes song selection, volume, intensity and silence commands to the song director.
class_name OvaniSongsAdministrator

## Notification for ovani music played.
signal ovani_music_played

## Looks up the function to run for each supported command name.
var handle_command_by_type: Dictionary
## Helper responsible for carrying out this system’s requests.
var director: OvaniSongsDirector


## Routes a named music command to its handler, ignoring commands while the engine's time scale
## differs from 1.
func command(arg: Variant) -> void:
    if Engine.time_scale != 1.0:
        return
    var final_args = arg.slice(1, arg.size())
    var parsed_arg = arg[Basics.FIRST].to_lower()
    handle_command_by_type[parsed_arg].call(final_args)


## Silences the dynamic song players when the other music system begins playback.
func on_sound_manager_played_music() -> void:
    director.silence_all()


## Converts command arguments and forwards a song-intensity change.
func on_set_intensity(args: Variant) -> void:
    var data: Dictionary = SystemHelpers.args_to_dict(args)
    director.relay_intensity(data)


## Notifies the other music system, converts command arguments and forwards a volume change.
func on_set_volume(args: Variant) -> void:
    ovani_music_played.emit()
    var data: Dictionary = SystemHelpers.args_to_dict(args)
    director.relay_volume(data)


## Notifies the other music system, converts command arguments and requests a song change.
func on_set_song(args: Variant) -> void:
    ovani_music_played.emit()
    var data: Dictionary = SystemHelpers.args_to_dict(args)
    director.set_new_song(data)


## Converts command arguments and fades the active song to silence over the requested time.
func on_set_silent(args: Variant) -> void:
    var data: Dictionary = SystemHelpers.args_to_dict(args)
    director.set_active_silent(data.time.to_float())


## Converts command arguments and forwards the song playback mode.
func on_set_mode(args) -> void:
    var data: Dictionary = SystemHelpers.args_to_dict(args)
    director.relay_mode(data)


## Queues the named song after the active player's current song.
func queue_song(song_name: String) -> void:
    director.queue_song(song_name)


## Requests playback of the song identified by the supplied name.
func play_song(song_name: String) -> void:
    director.play_song(song_name)


## Changes the active song's volume over the supplied transition duration.
func set_volume(volume: float, speed: float) -> void:
    director.set_volume(volume, speed)


## Changes the active song's intensity over the supplied transition duration.
func set_intensity(intensity: float, speed: float) -> void:
    director.set_intensity(intensity, speed)


## Requests that every song player fade to silence.
func mute_all() -> void:
    director.silence_all()


## Requests that the active song fade to silence over the supplied duration.
func mute_active(transition_time: float) -> void:
    director.set_active_silent(transition_time)


## Finds this system’s helper nodes, registers its command handlers and connects the notifications
## it responds to.
func _ready():
    director = get_child(0)
    VNSignalBus.music_played.connect(on_sound_manager_played_music)
    VNSignalBus.listen_for(ovani_music_played, Callable(VNSignalBus, "_on_ovani_music_played"))
    handle_command_by_type = {
        OvaniCommands.MUTE: on_sound_manager_played_music,
        OvaniCommands.INTENSITY: on_set_intensity,
        OvaniCommands.VOLUME: on_set_volume,
        OvaniCommands.SONG: on_set_song,
        OvaniCommands.SILENCE: on_set_silent,
        OvaniCommands.MODE: on_set_mode
    }
