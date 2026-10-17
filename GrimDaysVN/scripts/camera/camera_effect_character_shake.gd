# Editor configuration for CameraEffectCharacterShake.
@tool
extends Node
class_name CameraEffectCharacterShake

## Notification for complete.
signal complete
## Default duration in seconds of the camera shake.
var duration: float = 1.0
## Default strength of the camera shake.
var strength: float = 5.0
## Current smooth animation used by this effect; may be null before an animation starts.
var tween: Tween = null
## Camera containing this shake effect.
var parent_camera: Camera3D = null

## Whether test shake bool is currently enabled or true.
@export var test_shake_bool: bool:
    set(value):
        test_shake_bool = value
        if value:
            test_shake()
            test_shake_bool = false


## When the node enters the scene, this function sets [code]parent_camera[/code] to
## [code]parent[/code].
func _enter_tree() -> void:
    var parent = get_parent()
    if parent is not Camera3D:
        push_warning("Not currently parented to a camera...")
        return
    parent_camera = parent


## Runs a preview shake only when this script is running in the editor.
func test_shake() -> void:
    if not parent_camera:
        push_warning("No Parent Camera. Not executing")
        return
    shake()


## Runs a camera shake using the supplied duration and strength, then announces completion.
func shake(shake_length: float = duration, shake_strength: float = strength) -> void:
    var base_offset = parent_camera.position
    if tween:
        tween.kill()
    tween = get_tree().create_tween()
    await (
        tween
        . tween_method(
            func(delay: float):
                var xy_movement = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength * delay
                var movement = Vector3(xy_movement.x, xy_movement.y, 0.0)
                parent_camera.position = base_offset + xy_movement,
            1.0,
            0.0,
            shake_length
        )
        . finished
    )
    parent_camera.position = base_offset
    complete.emit()
