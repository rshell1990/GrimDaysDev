extends Node
## Moves the camera side to side for a horizontal impact effect.
class_name CameraHPunch


## Runs the camera’s horizontal punch movement, waiting for each movement step and restoring the
## zoom afterwards.
func start(speed, move_by, repeats, camera) -> void:
    var total_time = speed
    var sections: float = 4.0
    var section_time = total_time / sections

    await CameraCommonOperations.zoom_in(camera, section_time)

    for x in range(repeats):
        #Right
        await move_right(camera, move_by, section_time)
        #Center
        await move_left(camera, move_by, section_time)
        #Left
        await move_left(camera, move_by, section_time)
        #Center
        await move_right(camera, move_by, section_time)

    await CameraCommonOperations.zoom_out(camera, section_time)


## Smoothly changes horizontal position over time. It pauses for [code]tween.tween_property(camera,
## "global_position:x", camera.global_position.x + move_by, duration).finished[/code] before
## continuing.
func move_right(camera, move_by, duration) -> void:
    var tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
    await tween.tween_property(camera, "global_position:x", camera.global_position.x + move_by, duration).finished


## Smoothly changes horizontal position over time. It pauses for [code]tween.tween_property(camera,
## "global_position:x", camera.global_position.x - move_by, duration).finished[/code] before
## continuing.
func move_left(camera, move_by, duration) -> void:
    var tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
    await tween.tween_property(camera, "global_position:x", camera.global_position.x - move_by, duration).finished
