extends Panel
## Fixed round text value shared by all round display instances.
const ROUND_TEXT: String = "Round: "
## Fixed start animation value shared by all round display instances.
const START_ANIMATION: StringName = &"show"
## Fixed end animation value shared by all round display instances.
const END_ANIMATION: StringName = &"hide"
## Fixed animation pause value shared by all round display instances.
const ANIMATION_PAUSE: float = 2.0
## Configures the animator used by this round display.
@export var animator: AnimationPlayer
## Configures the label shadow used by this round display.
@export var label_shadow: Label
## Configures the label used by this round display.
@export var label: Label

## Runtime current round state used by this round display.
var current_round: int = 0
@export var production_mode: bool = false


## Initializes tree-dependent state as this node enters the scene tree.
func _enter_tree() -> void:
    if production_mode:
        return
    add_to_group(SignalBus.BATTLE_ROUND_PRESENTATION_GROUP)
    SignalBus.tick.connect(on_round_start)


## Handles the round start notification for this round display.
func on_round_start(request_id: StringName) -> void:
    CustomLogger.hint(self, on_round_start, "Displaying round start.", CustomLogger.LEVEL.VERY_VERBOSE)
    current_round += 1
    label.text = ROUND_TEXT + str(current_round)
    label_shadow.text = ROUND_TEXT + str(current_round)
    if not animator.is_node_ready():
        await animator.ready
    animator.play(START_ANIMATION)
    await get_tree().create_timer(AnimationTimes.LONG * ANIMATION_PAUSE).timeout
    animator.play(END_ANIMATION)
    await animator.animation_finished
    SignalBus.battle_round_presentation_finished.emit(request_id)


## The flow owns progression; old attempts cannot stop a newer announcement.
var _presentation_generation: int = 0


func present_round(number: int, continuation: Callable) -> void:
    _presentation_generation += 1
    var generation := _presentation_generation
    current_round = number
    label.text = ROUND_TEXT + str(number)
    label_shadow.text = label.text
    show()
    animator.play(START_ANIMATION)
    if not await _wait_animation(continuation, generation):
        return
    var until := Time.get_ticks_msec() + int(AnimationTimes.LONG * ANIMATION_PAUSE * 1000.0)
    while Time.get_ticks_msec() < until and continuation.call() and generation == _presentation_generation:
        await get_tree().process_frame
    if generation != _presentation_generation:
        return
    if not continuation.call():
        animator.stop()
        hide()
        return
    animator.play(END_ANIMATION)
    await _wait_animation(continuation, generation)
    if generation == _presentation_generation:
        hide()


func _wait_animation(continuation: Callable, generation: int) -> bool:
    var deadline := Time.get_ticks_msec() + 5000
    while (
        animator.is_playing()
        and continuation.call()
        and generation == _presentation_generation
        and Time.get_ticks_msec() < deadline
    ):
        await get_tree().process_frame
    if generation != _presentation_generation:
        return false
    if not continuation.call() or animator.is_playing():
        animator.stop()
        hide()
        return false
    return true
