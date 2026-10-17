extends Node


## Smoothly narrows the camera's field of view over the supplied duration.
func zoom_in(camera, duration) -> void:
    var tween := create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
    await tween.tween_property(camera, "fov", DDCameraSettings.ZOOM_FOV, duration).finished


## Smoothly restores the camera's normal field of view over the supplied duration.
func zoom_out(camera, duration) -> void:
    var tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
    await tween.tween_property(camera, "fov", DDCameraSettings.DEFAULT_FOV, duration).finished
