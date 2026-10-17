# Editor configuration for SpineSpriteOverride.
@icon("res://GrimDays/assets/visuals/editor_icons/strong.svg")
extends SpineSprite
class_name SpineSpriteOverride
@export var default_animation_name: String
## Minimum randomized startup phase of the idle animation, in seconds.
const MIN_DELAY: float = 0.02
## Maximum randomized startup phase of the idle animation, in seconds.
const MAX_DELAY: float = 0.85


## Makes Spine update its animation during physics updates instead of the default update mode.
func _ready() -> void:
    if not skeleton_data_res:
        return
    update_mode = SpineConstant.UpdateMode_Physics
    if not default_animation_name.is_empty():
        play_animation(default_animation_name)


## Play the supplied animation if it exists without looping on track 0 unless overridden, then restart the
## default_animation_name if it exists.
func play_animation(animation_name: String, loop: bool = false, track_number: int = 0) -> void:
    if not skeleton_data_res:
        CustomLogger.warn(
            self, play_animation, get_parent().name + "is missing skeleton_data_res", CustomLogger.LEVEL.MILD
        )
        return

    var animation_state: SpineAnimationState = get_animation_state()

    if not get_animation_state():
        CustomLogger.warn(
            self, play_animation, get_parent().name + "could not get animation state.", CustomLogger.LEVEL.MILD
        )
        return

    if not check_for_animation(animation_name):
        return

    if animation_name != default_animation_name:
        animation_state.set_animation(animation_name, loop, track_number)
        if loop:
            return
        await animation_completed

    if default_animation_name.is_empty():
        CustomLogger.warn(
            self, play_animation, get_parent().name + "No default animation set.", CustomLogger.LEVEL.MILD
        )
        return
    animation_state.set_animation(default_animation_name, true, 0)
    var track = animation_state.get_track(0)
    var track_length = track.get_track_time()
    track.set_track_time(randf_range(track_length * MIN_DELAY, track_length * MAX_DELAY))


## Check if the supplied animaiton name is in the animation list of the current skeleton.
func check_for_animation(animation_name: String) -> bool:
    if not skeleton_data_res:
        CustomLogger.warn(
            self, check_for_animation, get_parent().name + "is missing skeleton_data_res", CustomLogger.LEVEL.MILD
        )
        return false

    var has_animation: bool = false

    var animation_list: Array = skeleton_data_res.get_animations()
    var animation_list_plain: Array[String] = []
    for spine_animation: SpineAnimation in animation_list:
        animation_list_plain.append(spine_animation.get_name())
        spine_animation.get_duration()

    if not animation_name in animation_list_plain:
        CustomLogger.warn(
            self,
            check_for_animation,
            get_parent().name + "animation named: " + animation_name + " is not in : " + str(animation_list_plain),
            CustomLogger.LEVEL.MILD
        )
    else:
        has_animation = true

    return has_animation


## Get the length of a spine animation by name if it is available on this spine sprite.
func get_animation_length(animation_name: String) -> float:
    if not skeleton_data_res:
        CustomLogger.warn(
            self, get_animation_length, get_parent().name + "is missing skeleton_data_res", CustomLogger.LEVEL.MILD
        )
        return 0.0

    if not check_for_animation(animation_name):
        return 0.0

    var length: float = 0.0

    var animation_list: Array = skeleton_data_res.get_animations()
    var animation_list_plain: Array[String] = []
    for spine_animation: SpineAnimation in animation_list:
        if spine_animation.get_name() == animation_name:
            length = spine_animation.get_duration()
            break

    return length
