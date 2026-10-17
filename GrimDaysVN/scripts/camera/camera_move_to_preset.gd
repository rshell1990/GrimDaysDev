extends Node
## Moves the main view to match another camera, including its visual-processing settings.
class_name MoveToSpecificCamera


## Sets [code]main_camera.cull_mask[/code] to [code]target_camera.cull_mask[/code]. It pauses for
## [code]fade_flag.get_and_set_screen_shot()[/code],
## [code]move_camera_and_fade_screenshot(fade_flag, main_camera, target_camera, duration)[/code]
## before continuing.
func execute(target_camera, main_camera, duration) -> void:
    var main_attributes: CameraAttributesPractical = main_camera.attributes
    var other_attributes: CameraAttributesPractical = target_camera.attributes
    var fade_flag = get_node("/root/UIDirector/Fade Flag")

    #await blur_view(main_attributes)
    await fade_flag.get_and_set_screen_shot()

    main_camera.cull_mask = target_camera.cull_mask

    await move_camera_and_fade_screenshot(fade_flag, main_camera, target_camera, duration)
    #await match_target_camera_post_processing(main_attributes, other_attributes)


## Changes the camera attributes to blur the view during a transition.
func blur_view(main_attributes) -> void:
    var tween = create_tween().set_ease(Tween.EASE_OUT).set_parallel()
    tween.tween_property(main_attributes, "dof_blur_far_distance", 200.0, VNAnimationTimes.FAST)
    tween.tween_property(main_attributes, "dof_blur_far_transition", 1.0, VNAnimationTimes.FAST)
    await tween.tween_property(main_attributes, "dof_blur_amount", 0.2, VNAnimationTimes.FAST).finished


## Smoothly changes [code]global_transform[/code] over time. It pauses for
## [code]tween.tween_property(main_camera, "global_transform", target_camera.global_transform,
## duration).finished[/code] before continuing.
func move_camera_and_fade_screenshot(fade_flag, main_camera, target_camera, duration) -> void:
    var tween = create_tween()
    fade_flag.fade_screenshot()
    await tween.tween_property(main_camera, "global_transform", target_camera.global_transform, duration).finished


## Copies the target camera's visual-processing settings to the main camera's attributes.
func match_target_camera_post_processing(main_attributes, other_attributes) -> void:
    var tween = create_tween()
    tween.set_parallel().set_ease(Tween.EASE_OUT)
    tween.tween_property(
        main_attributes, "dof_blur_far_distance", other_attributes.dof_blur_far_distance, VNAnimationTimes.FAST
    )
    tween.tween_property(
        main_attributes, "dof_blur_far_transition", other_attributes.dof_blur_far_transition, VNAnimationTimes.FAST
    )
    await (
        tween
        . tween_property(main_attributes, "dof_blur_amount", other_attributes.dof_blur_amount, VNAnimationTimes.FAST)
        . finished
    )
