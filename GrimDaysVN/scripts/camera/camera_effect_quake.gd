extends Node
## Moves the camera diagonally in a repeated quake pattern.
class_name CameraQuake


## Runs the camera’s quake movement, waiting for each movement step and restoring the zoom
## afterwards.
func start(speed, move_by, repeats, camera) -> void:
    var total_time = speed
    var sections: float = 8.0
    var section_time = total_time / sections

    await CameraCommonOperations.zoom_in(camera, section_time)

    for x in range(repeats):
        # UP RIGHT
        await move_diagnol_up_right(camera, move_by, move_by, section_time)
        # CENTER
        await move_diagnol_down_left(camera, move_by, move_by, section_time)
        # DOWN LEFT
        await move_diagnol_down_left(camera, move_by, move_by, section_time)
        # CENTER
        await move_diagnol_up_right(camera, move_by, move_by, section_time)
        # DOWN RIGHT
        await move_diagnol_down_right(camera, move_by, move_by, section_time)
        # CENTER
        await move_diagnol_up_left(camera, move_by, move_by, section_time)
        # UP LEFT
        await move_diagnol_up_left(camera, move_by, move_by, section_time)
        # CENTER
        await move_diagnol_down_right(camera, move_by, move_by, section_time)

    await CameraCommonOperations.zoom_out(camera, section_time)


## Moves the camera diagonally down and right over the supplied duration.
func move_diagnol_down_right(camera, move_x_by, move_y_by, duration) -> void:
    var tween = create_tween().set_parallel().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(camera, "global_position:x", camera.global_position.x + move_x_by, duration)
    await tween.tween_property(camera, "global_position:y", camera.global_position.y + move_y_by, duration).finished


## Moves the camera diagonally down and left over the supplied duration.
func move_diagnol_down_left(camera, move_x_by, move_y_by, duration) -> void:
    var tween = create_tween().set_parallel().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(camera, "global_position:x", camera.global_position.x - move_x_by, duration)
    await tween.tween_property(camera, "global_position:y", camera.global_position.y + move_y_by, duration).finished


## Moves the camera diagonally up and right over the supplied duration.
func move_diagnol_up_right(camera, move_x_by, move_y_by, duration) -> void:
    var tween = create_tween().set_parallel().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(camera, "global_position:x", camera.global_position.x + move_x_by, duration)
    await tween.tween_property(camera, "global_position:y", camera.global_position.y - move_y_by, duration).finished


## Moves the camera diagonally up and left over the supplied duration.
func move_diagnol_up_left(camera, move_x_by, move_y_by, duration) -> void:
    var tween = create_tween().set_parallel().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(camera, "global_position:x", camera.global_position.x - move_x_by, duration)
    await tween.tween_property(camera, "global_position:y", camera.global_position.y - move_y_by, duration).finished
