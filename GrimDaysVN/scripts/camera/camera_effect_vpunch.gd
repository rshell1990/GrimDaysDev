extends Node
## Moves the camera up and down for a vertical impact effect.
class_name CameraVpunch


## Runs the camera’s vertical punch movement, waiting for each movement step and restoring the zoom
## afterwards.
func start(speed, move_by, repeats, camera) -> void:
    var total_time = speed
    var sections := 4.0
    var section_time = total_time / sections

    await CameraCommonOperations.zoom_in(camera, section_time)

    for x in range(repeats):
        #DOWN
        await move_down(camera, move_by, section_time)
        #CENTER
        await move_up(camera, move_by, section_time)
        #UP
        await move_up(camera, move_by, section_time)
        #CENTER
        await move_down(camera, move_by, section_time)

    await CameraCommonOperations.zoom_out(camera, section_time)


## Smoothly changes vertical position over time. It pauses for [code]tween.tween_property(camera,
## "global_position:y", camera.global_position.y + move_by, duration).finished[/code] before
## continuing.
func move_down(camera, move_by, duration) -> void:
    var tween = create_tween().set_parallel().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
    await tween.tween_property(camera, "global_position:y", camera.global_position.y + move_by, duration).finished


## Smoothly changes vertical position over time. It pauses for [code]tween.tween_property(camera,
## "global_position:y", camera.global_position.y - move_by, duration).finished[/code] before
## continuing.
func move_up(camera, move_by, duration) -> void:
    var tween = create_tween().set_parallel().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
    await tween.tween_property(camera, "global_position:y", camera.global_position.y - move_by, duration).finished
