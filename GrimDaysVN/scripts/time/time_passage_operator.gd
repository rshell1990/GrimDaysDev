extends LoadableCanvasLayer
##

## Animation player used for animator.
@export var animator: AnimationPlayer
## Stored dawn time used by this script’s update and input handling.
@export var dawn_time: float
## Stored morning time used by this script’s update and input handling.
@export var morning_time: float
## Stored afternoon time used by this script’s update and input handling.
@export var afternoon_time: float
## Stored evening time used by this script’s update and input handling.
@export var evening_time: float
## Stored night time used by this script’s update and input handling.
@export var night_time: float
## Stored bedtime time used by this script’s update and input handling.
@export var bedtime_time: float
## Stored new day time used by this script’s update and input handling.
@export var new_day_time: float

## Stored beginning time used by this script’s update and input handling.
var beginning_time: TimeAdministrator.TIMES
## Stored ending time used by this script’s update and input handling.
var ending_time: TimeAdministrator.TIMES

## Current visual work is owned by one time-state visit.
var _tween: Tween


func _owns(token: int) -> bool:
    return GameManager.state_manager.owns_state(GameManagerStates.STATES.TimeChanging, token)


## Stops visual work when a different state supersedes the time transition.
func cancel_passage() -> void:
    if _tween and _tween.is_valid():
        _tween.kill()
    animator.stop()
    visible = false
    get_child(0).modulate.a = Basics.TRANSPARENT


## Every await checks ownership before touching the UI or completing the state.
func show_passage(start_time: TimeAdministrator.TIMES, new_time: TimeAdministrator.TIMES, token: int) -> void:
    if not _owns(token):
        return
    if start_time == new_time:
        GameManager.state_manager.complete_state(GameManagerStates.STATES.TimeChanging, token)
        return
    beginning_time = start_time
    ending_time = new_time
    var start_animation_time: float = (
        get_time(beginning_time) if beginning_time != TimeAdministrator.TIMES.Bedtime else bedtime_time
    )
    var end_animation_time: float = (
        get_time(ending_time) if beginning_time != TimeAdministrator.TIMES.Bedtime else new_day_time
    )
    animator.seek(start_animation_time, true)
    await get_tree().create_timer(VNAnimationTimes.STANDARD).timeout
    if not _owns(token):
        return
    _tween = create_tween()
    _tween.tween_property(get_child(0), "modulate:a", Basics.OPAQUE, VNAnimationTimes.FAST)
    # Frame waits also terminate when cancellation kills a tween or stops animation.
    while _owns(token) and _tween.is_running():
        await get_tree().process_frame
    if not _owns(token):
        return
    if end_animation_time < start_animation_time:
        end_animation_time = (
            animator.get_animation_library(animator.get_animation_library_list()[0]).get_animation("time passes").length
        )
    animator.play_section("time passes", start_animation_time, end_animation_time)
    while _owns(token) and animator.is_playing():
        await get_tree().process_frame
    if not _owns(token):
        return
    await get_tree().create_timer(1.5).timeout
    if not _owns(token):
        return
    _tween = create_tween()
    _tween.tween_property(get_child(0), "modulate:a", Basics.TRANSPARENT, VNAnimationTimes.FAST)
    while _owns(token) and _tween.is_running():
        await get_tree().process_frame
    if _owns(token):
        GameManager.state_manager.complete_state(GameManagerStates.STATES.TimeChanging, token)


## Returns the configured duration for the requested time of day, using the dawn duration as the
## fallback.
func get_time(id: TimeAdministrator.TIMES) -> float:
    match id:
        TimeAdministrator.TIMES.Morning:
            return morning_time
        TimeAdministrator.TIMES.Afternoon:
            return afternoon_time
        TimeAdministrator.TIMES.Evening:
            return evening_time
        TimeAdministrator.TIMES.Night:
            return night_time
        TimeAdministrator.TIMES.Bedtime:
            return bedtime_time

    return dawn_time
