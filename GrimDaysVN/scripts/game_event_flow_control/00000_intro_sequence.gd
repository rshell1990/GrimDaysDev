extends Node

## Scene node used for animator, found when this node is ready.
@onready var animator: AnimationPlayer = %SequenceAnimations


## Plays background ambience through [code]SoundManager[/code].
func start_audio() -> void:
    SoundManager.play_ambient_sound(
        Repositories.get_info(RepositoryTypes.AMBIENT, "tyrannic_breathing")
    )


## Connects responses to [code]Dialogic.timeline_ended[/code]; starts the selected dialogue
## timeline.
func start_first_timeline() -> void:
    var timeline_path := (
        "res://GrimDaysVN/resources/dialogic/timelines/launch/fenton_works/"
        + "00000_fenton_works_sequence_intro_a_black_screen.dtl"
    )
    Dialogic.start(timeline_path)
    Dialogic.timeline_ended.connect(trigger_second_animation)


## Disconnects responses from [code]Dialogic.timeline_ended[/code]; starts playback on
## [code]animator[/code].
func trigger_second_animation() -> void:
    Dialogic.timeline_ended.disconnect(trigger_second_animation)
    #animator.play("1")
    animator.play("1_2")


## Connects responses to [code]Dialogic.timeline_ended[/code]; starts the selected dialogue
## timeline.
func start_second_timeline() -> void:
    var timeline_path := (
        "res://GrimDaysVN/resources/dialogic/timelines/launch/fenton_works/"
        + "00000_fenton_works_sequence_intro_b.dtl"
    )
    Dialogic.start(timeline_path)
    Dialogic.timeline_ended.connect(trigger_third_animation)


## Disconnects responses from [code]Dialogic.timeline_ended[/code]; starts playback on
## [code]animator[/code].
func trigger_third_animation() -> void:
    Dialogic.timeline_ended.disconnect(trigger_third_animation)
    #animator.play("2")
    animator.play("2_2")


## Starts the selected dialogue timeline.
func start_third_timeline() -> void:
    var timeline_path := (
        "res://GrimDaysVN/resources/dialogic/timelines/launch/fenton_works/"
        + "00000_fenton_works_sequence_intro_c.dtl"
    )
    Dialogic.start(timeline_path)


## Currently performs no work; this function is a placeholder for behavior supplied later or by a
## child script.
func start_scene_three() -> void:
    #var timeline_path := (
    #    "res://GrimDaysVN/resources/dialogic/timelines/"
    #    + "00000_fenton_works_sequence_intro_e.dtl"
    #)
    #Dialogic.start(timeline_path)
    pass


## Plays a sound through [code]SoundManager[/code].
func play_ecto_blast() -> void:
    SoundManager.play_sound(Repositories.get_info(RepositoryTypes.SOUNDS, "ghost-ray-1"))


## Changes the sequence animation speed for the current animation, using its completion notification
## to handle the transition.
func change_animator_speed_for_this_animation(new_speed: float) -> void:
    var old_speed = animator.speed_scale
    animator.speed_scale = new_speed
    await animator.animation_finished
    animator.speed_scale = old_speed


## Plays a sound through [code]SoundManager[/code].
func tyrannic_fully_enters() -> void:
    SoundManager.play_sound(Repositories.get_info(RepositoryTypes.SOUNDS, "tyrannic-screams"))


## Currently performs no work; this function is a placeholder for behavior supplied later or by a
## child script.
func free_assets_1() -> void:
    #%"Scene 1 - Danny BG".queue_free()
    #%"Scene 1 - Danny Normal".queue_free()
    #%"Scene 1 - Danny Talk".queue_free()
    #%"Scene 1 - Sam Bg".queue_free()
    #%"Scene 1 - Sam Normal".queue_free()
    #%"Scene 1 - Sam Talk".queue_free()
    pass
