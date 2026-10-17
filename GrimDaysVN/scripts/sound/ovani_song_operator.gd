## Adapts an Ovani song player to the project's resource lookup and playback controls.
@tool
class_name OvaniSongOperator
extends OvaniPlayer
## Shared fixed value for muted.
const MUTED: float = -80.0
## Shared fixed value for sound treshold.
const SOUND_TRESHOLD: float = -75.0
## Shared fixed value for start volume.
const START_VOLUME: float = -40.0
## Shared fixed value for starting intensity.
const STARTING_INTENSITY = 0.0
## Lookup table for song modes; keys select the corresponding stored values.
const SONG_MODES: Dictionary = {
    "short": DDOvaniSong.OvaniMode.Loop30,
    "long": DDOvaniSong.OvaniMode.Loop60,
    "intensity": DDOvaniSong.OvaniMode.Intensities
}

## ID of the song currently selected by this player.
var playing: String


## Runs the parent script’s version of this function with the supplied arguments.
func _ready() -> void:
    super()


# func _physics_process(delta: float) -> void:
# 	if QueuedSongs.is_empty():
# 		return
# 	if Volume < -79.0:
# 		QueuedSongs.clear()


## Use this to transition the current Intensity over time. [br]
## It's a simple alternative to setting the Intensity manually yourself each frame.
func set_intensity(intensity: float, transitionTime: float):
    SystemHelpers.print_rich(
        "[color=#0F5]Setting intensity to: ", str(intensity), " over ", str(transitionTime), " seconds.[/color]"
    )
    var tween = create_tween()
    tween.tween_property(self, "Intensity", intensity, transitionTime)


## Use this to transition the current Decibel Volume over time. [br]
## It's a simple alternative to setting the Volume manually yourself each frame.
func set_volume(volume: float, transitionTime: float):
    SystemHelpers.print_rich(
        "[color=#0F5]Setting volume to: ", str(volume), " over ", str(transitionTime), " seconds.[/color]"
    )
    var tween = create_tween()
    tween.tween_property(self, "Volume", volume, transitionTime)


## Sets [code]playing[/code] to [code]final_song.id[/code].
func play(new_song) -> void:
    var final_song = new_song
    if typeof(new_song) == TYPE_STRING:
        final_song = ResourceLoader.load(final_song, "", ResourceLoader.CACHE_MODE_IGNORE)

    SystemHelpers.print_rich("[color=#0F5]Playing: ", str(final_song.id), ".[/color]")
    playing = final_song.id
    # if Volume < SOUND_TRESHOLD:
    # 	set_volume(START_VOLUME, VNAnimationTimes.SLOW)
    PlaySongNow(final_song)


## Accepts a song resource or loads one from a path, then adds it to the song queue.
func queue(new_song) -> void:
    var final_song = new_song
    if typeof(new_song) == TYPE_STRING:
        final_song = ResourceLoader.load(final_song, "", ResourceLoader.CACHE_MODE_IGNORE)
    SystemHelpers.print_rich("[color=#0F5]Queuing: ", str(final_song.id), ".[/color]")
    # if Volume < SOUND_TRESHOLD:
    # 	set_volume(START_VOLUME, VNAnimationTimes.SLOW)
    QueueSong(final_song)


## Changes the first queued song's playback mode using the named mode lookup. Requires at least one
## queued song.
func set_mode(new_mode) -> void:
    QueuedSongs[0].SongMode = SONG_MODES[new_mode]
