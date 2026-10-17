extends Node
## Moves a camera toward supplied position and zoom settings.
class_name CameraMoveTo


## Smoothly changes camera zoom, [code]global_transform[/code] over time; stops [code]tween[/code];
## waits for a timer through [code]SystemHelpers[/code]. It also sets [code]Dialogic.paused[/code]
## to false. It pauses for [code]tween.tween_property(camera, "global_transform", new_position,
## time).finished[/code], [code]SystemHelpers.start_timer(VNAnimationTimes.FAST)[/code] before
## continuing.
func execute(camera: Camera3D, args) -> void:
    var data = args
    Dialogic.paused = true
    var x = float(data.x)
    var y = float(data.y)
    var z = float(data.z)
    var new_fov = float(data.fov)
    var current_fov = camera.fov

    var new_position: Transform3D = Transform3D(Basis(), Vector3(x, y, z))
    # var new_dof_distance = data.dist
    # var new_dof_amount = data.amount
    var time = float(data.duration)

    var tween = create_tween()

    tween.set_parallel().set_ease(Tween.EASE_OUT)
    if new_fov != current_fov:
        tween.tween_property(camera, "fov", new_fov, time)
    await tween.tween_property(camera, "global_transform", new_position, time).finished
    tween.stop()
    Dialogic.paused = false
    await SystemHelpers.start_timer(VNAnimationTimes.FAST)
