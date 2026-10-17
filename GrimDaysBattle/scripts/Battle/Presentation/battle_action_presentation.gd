extends Node
## Moves units during actions, with a time limit so unfinished movement cannot hold up battle
## forever.
class_name BattleActionPresentation

## Time in seconds for each smooth movement toward a target or back to the starting position.
@export_range(0.0, 2.0) var movement_seconds: float = 0.2
## Current smooth movement animation, stopped when the action's display is cancelled.
var _tween: Tween
## Acting unit's display, temporarily moved and drawn in front of other units.
var _display: Unit2DDisplay
## Unit's position in the scene before moving toward its target; restored afterwards or on
## cancellation.
var _origin: Vector2


## Moves the acting unit partway toward its target and waits up to a time limit.
## Calls continuation to check whether the battle still allows the movement to continue.
func approach(stage: BattleVisualStage, actor: BattleUnit, target: BattleUnit, continuation: Callable) -> void:
    cancel()
    if not is_instance_valid(stage) or not continuation.call():
        return
    var display := stage.get_unit_display(actor)
    var destination := stage.get_unit_display(target)
    if not is_instance_valid(display) or not is_instance_valid(destination) or display == destination:
        return
    _display = display
    _origin = display.global_position
    display.z_index = 25
    display.on_switch_to_combat_camera(actor)
    _tween = display.create_tween()
    _tween.tween_property(display, "global_position", _origin.lerp(destination.global_position, 0.35), movement_seconds)
    await _wait_for_motion(continuation)


## Waits for the unit to move back to its starting position, then resets its camera and drawing
## order.
func return_actor(continuation: Callable) -> void:
    if is_instance_valid(_display) and continuation.call():
        _tween = _display.create_tween()
        _tween.tween_property(_display, "global_position", _origin, movement_seconds)
        await _wait_for_motion(continuation)
    cancel()


## Stops movement immediately and resets the unit's starting position, drawing order and camera.
func cancel() -> void:
    if _tween and _tween.is_valid():
        _tween.kill()
    _tween = null
    if is_instance_valid(_display):
        _display.global_position = _origin
        _display.z_index = 0
        _display.on_switch_away_from_combat_camera()
    _display = null


## Checks each frame whether movement has ended or must stop.
## Stops waiting if continuation returns false or the movement duration plus 0.25 seconds has
## passed.
func _wait_for_motion(continuation: Callable) -> void:
    var deadline := Time.get_ticks_msec() + int((movement_seconds + 0.25) * 1000.0)
    while _tween and _tween.is_valid() and _tween.is_running():
        if not continuation.call() or Time.get_ticks_msec() >= deadline:
            break
        await get_tree().process_frame


## Stops movement and resets the unit display when this helper leaves the scene.
func _exit_tree() -> void:
    cancel()
