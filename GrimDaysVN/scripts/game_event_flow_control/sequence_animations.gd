# Editor configuration for SequenceAnimator.
@icon("res://GrimDays/assets/visuals/editor_icons/family-tree.svg")
extends AnimationPlayer
## A custom subclass of the animation player specifically to handle trigger
## certain functions during a sequenced event.
class_name SequenceAnimator
## Name of the animation to start next.
var next_animation: String


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
    VNSignalBus.play_animation.connect(on_animation_signal)
    animation_started.connect(on_animation_start.bind(speed_scale))


## Sets the animation player's speed to the value supplied with the start request.
func on_animation_start(_animation_name, starting_speed) -> void:
    speed_scale = starting_speed


## Requests that the scene-transition cover be shown.
func show_fade_flag() -> void:
    UIDirector.fade_flag_show()


## Requests that the scene-transition cover be hidden.
func hide_fade_flag() -> void:
    UIDirector.fade_flag_hide()


## Use the sound manager to play the sound effect specified.
func play_sound(sound_name: String) -> void:
    SoundManager.play_sound(Repositories.get_info(RepositoryTypes.SOUNDS, sound_name))


## Use the sound manager to play the sound effect specified.
func play_sound_at_pitch(sound_name: String, pitch: float) -> void:
    SoundManager.play_sound_with_pitch(
        Repositories.get_info(RepositoryTypes.SOUNDS, sound_name), pitch
    )


## Use the sound manager to play the ambient sound specified.
func play_ambient(ambient_name: String) -> void:
    SoundManager.play_ambient_sound(Repositories.get_info(RepositoryTypes.AMBIENT, ambient_name))


## Use the sound manager to stop the ambient sound specified.
func stop_ambient(ambient_name: String) -> void:
    SoundManager.stop_ambient_sound(ambient_name)


## Use the sound manager to play the simple music specified.
func play_music(music_name: String) -> void:
    SoundManager.play_music(Repositories.get_info(RepositoryTypes.MUSIC, music_name))


## Requests that music fade out over the supplied duration.
func stop_music(fade_time: float) -> void:
    SoundManager.stop_music(fade_time)


## Use the sound manager to play the advanced ovani song specified.
func start_song(song_name: String, volume: float) -> void:
    SoundManager.play_song(song_name, volume)


## Use the sound manager to update the currently playing ovani song.
func update_song(volume: float, intensity: float, transition_time: float) -> void:
    SoundManager.update_song(volume, intensity, transition_time)


## Use the sound manager to stop all persistent audio, good to call when starting the sequence.
func stop_audio(transition_time: float) -> void:
    SoundManager.stop_all_ambient_sounds(transition_time)
    SoundManager.stop_music(transition_time)
    SoundManager.stop_song(transition_time)


## Scale the animation player's scene briefly, then reset after the current animation ends.
func change_speed_for_this_animation(new_speed: float) -> void:
    var old_speed = speed_scale
    pause()
    speed_scale = new_speed
    play()
    await animation_finished
    speed_scale = old_speed


## Handles the sequence's skip input through its configured animation behavior.
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("accept"):
        if is_playing():
            change_speed_for_this_animation(20.0)


## Start a Dialogic timeline, optionally specify an animation that is chained
## when the timeline ends.
func trigger_timeline(new_timeline: Variant, ending_animation: String = "") -> void:
    CustomLogger.hint(
        self,
        self.trigger_timeline,
        " will trigger: " + str(new_timeline) + " and has an ending animation of:"
        + ending_animation,
        3
    )
    if not Dialogic.current_timeline == new_timeline:
        Dialogic.start(new_timeline)
    next_animation = ending_animation
    if Dialogic.timeline_ended.is_connected(on_timeline_end):
        Dialogic.timeline_ended.disconnect(on_timeline_end)
    Dialogic.timeline_ended.connect(on_timeline_end)


## When the timeline ends, disconnect from the timeline_ended signal and then if
## the next animation isn't empty, play that animation.
func on_timeline_end() -> void:
    Dialogic.timeline_ended.disconnect(on_timeline_end)
    if next_animation.is_empty():
        return

    play(next_animation)


## When the Signal Bus emits to play animation, will play the specified
## animation if the instanced SequenceAnimator's animation library has an
## animation of the string emitted from theVNSignalBus.
func on_animation_signal(animation_name: String, await_finished: bool = true) -> void:
    if not has_animation(animation_name):
        return
    if Dialogic.Animations.is_animating():
        await Dialogic.Animations.finished
    if is_playing():
        await animation_finished
    CustomLogger.warn(
        self,
        self.on_animation_signal,
        " recieved: " + animation_name + " to play.  So Dialogic will be paused.",
        CustomLogger.LEVEL.VERBOSE
    )
    Dialogic.paused = true
    play(animation_name)
    if not await_finished:
        CustomLogger.warn(
            self,
            self.on_animation_signal,
            " is not awaiting the animation to finish, Dialogic will be unpaused.",
            CustomLogger.LEVEL.VERBOSE
        )
        Dialogic.paused = false
        return
    await animation_finished
    CustomLogger.warn(
        self,
        self.on_animation_signal,
        animation_name + " has finished.  So Dialogic will be unpaused.",
        CustomLogger.LEVEL.VERBOSE
    )
    Dialogic.paused = false
