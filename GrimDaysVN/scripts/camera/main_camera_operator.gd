# Editor configuration for MainCameraOperator.
@icon("res://GrimDays/assets/visuals/at-icons/node3d/photo_camera.svg")
extends Camera3D
## Applies movement, effects and saved settings to the main scene camera.
class_name MainCameraOperator
## Helper that moves the main camera to an existing camera preset.
var camera_mover: MoveToSpecificCamera
## Helper that moves the main camera using supplied position and zoom settings.
var camera_custom_mover: CameraMoveTo
## Lookup table for camera effects; keys select the corresponding stored values.
var camera_effects: Dictionary
## Coordinates used for original position.
var original_position: Vector3
## Camera field of view before temporary zoom effects.
var original_fov: float


## When the node enters the scene, this function sends [code]VNSignalBus.main_camera_entered[/code]
## notifications.
func _enter_tree() -> void:
    VNSignalBus.main_camera_entered.emit(self)


## Selects the requested camera effect and runs it. Waits for shake completion or for a duration
## based on the requested speed and repeat count.
func run_effect(args) -> void:
    var effect = camera_effects[args.fx.to_lower()]
    if "shake" in effect:
        effect.shake(float(args.duration), float(args.strength))
        await effect.complete
        return

    var speed = float(args.speed)
    var repeats = int(args.repeats)
    var movement = CameraEffects.MOVEMENTS[args.fx.to_lower()]
    effect.start(speed, movement, repeats, self)
    await get_tree().create_timer(speed * repeats + 0.5).timeout


## Starts movement to the supplied camera preset, then waits for the requested duration plus the
## standard animation allowance.
func move_to_specific_camera(camera, data) -> void:
    var time = float(data.time)
    camera_mover.execute(camera, self, time)
    await get_tree().create_timer(time + VNAnimationTimes.STANDARD).timeout


## Starts movement using the supplied custom camera arguments, then waits for the standard animation
## allowance.
func move_to_custom(args) -> void:
    camera_custom_mover.execute(self, args)
    await get_tree().create_timer(VNAnimationTimes.STANDARD).timeout


## Applies the supplied camera transform and visible-layer mask to this camera.
func load(args: Dictionary) -> void:
    global_transform = args.camera_pos
    cull_mask = args.cull_mask


## When the node is ready, this function adds [code]new_effect[/code] as a child node; sets
## [code]camera_mover[/code] to [code]get_child(0)[/code]; sets [code]camera_custom_mover[/code] to
## [code]get_child(1)[/code]. It also sets [code]original_position[/code] to
## [code]global_position[/code].
func _ready():
    camera_mover = get_child(0)
    camera_custom_mover = get_child(1)
    original_position = global_position
    original_fov = fov
    for effects in Repositories.get_repository(RepositoryTypes.CAMERAFX).master.keys():
        var new_effect = Repositories.get_info(RepositoryTypes.CAMERAFX, effects).instantiate()
        add_child(new_effect)
        camera_effects[effects] = new_effect


## Returns the camera transform and visible-layer mask for the camera director's save data.
func _get_state() -> Dictionary:
    return {
        "camera_pos": global_transform,
        "cull_mask": cull_mask,
    }


## Returns visibility, the scene-wide transform, and the mask selecting which layers the camera can
## see.
func get_state() -> Dictionary:
    var state: Dictionary
    state = {"visible": visible, "global_transform": global_transform, "cull_mask": cull_mask}
    return state


## Restores visibility, transform and visible-layer mask when the supplied state is not already
## equal to the current state.
func restore_state(state: Dictionary) -> void:
    var current_state = get_state()
    if current_state.keys() != state.keys():
        CustomLogger.warn(self, restore_state, "Mismatching keys...", CustomLogger.LEVEL.MILD)
        return
    visible = state.visible
    global_transform = state.global_transform
    cull_mask = state.cull_mask
