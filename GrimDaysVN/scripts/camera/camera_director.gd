## Finds scene cameras, routes camera requests and keeps camera state for restoration.
class_name CameraDirector
extends Node
## Notification for restored.
signal restored

## Key used to identify this script’s data in saved state.
var save_name: String = "camera"

## Main scene camera currently used by the camera director.
var main_camera: MainCameraOperator

## Lookup table for phantom cameras; keys select the corresponding stored values.
var phantom_cameras: Dictionary

## Previously supplied state kept for later restoration.
var old_data: Dictionary


## When the node enters the scene, this function registers [code]self[/code] with
## [code]SaveAndLoadSystemManager[/code].
func _enter_tree() -> void:
    SaveAndLoadSystemManager.add_node(self)


## When the node is ready, this function connects responses to
## [code]VNSignalBus.main_camera_entered[/code].
func _ready() -> void:
    VNSignalBus.main_camera_entered.connect(reconnect_cameras)


## Finds the main camera and available camera presets in the current scene.
func reconnect_cameras(supplied_camera = null) -> void:
    #SystemHelpers.print("Reconnect Camera on Director.")
    var root = get_node("/root")
    var root_tree = root.get_tree()
    main_camera = null
    phantom_cameras = {}
    if supplied_camera == null:
        var main_cameras = root_tree.get_nodes_in_group(DDNodeTypes.MAIN_CAMERA)
        for camera in main_cameras:
            main_camera = camera
    else:
        main_camera = supplied_camera

    var phantom_camera_nodes = root_tree.get_nodes_in_group(DDNodeTypes.PHANTOM_CAMERA)
    phantom_camera_nodes.sort_custom(func(a, b): return a.global_position.z > b.global_position.z)

    for camera in phantom_camera_nodes:
        phantom_cameras[camera.name.to_lower()] = camera

    if not old_data.is_empty():
        relay_load(old_data)
        old_data.clear()


## Reconnects cameras when needed and asks the main camera to run the supplied effect.
func relay_effect(data: Dictionary) -> void:
    if not main_camera:
        reconnect_cameras()
    main_camera.run_effect(data)


## Finds the current cameras and sends the movement request to the appropriate camera helper.
func relay_move(data) -> void:
    if not main_camera:
        reconnect_cameras()
    var camera_name = data.name
    var final_args = data
    if phantom_cameras.is_empty():
        reconnect_cameras()
    if camera_name in phantom_cameras.keys():
        main_camera.move_to_specific_camera(phantom_cameras[camera_name], final_args)
    elif data.has("reset"):
        var new_args: Dictionary = {
            "x": main_camera.original_position.x,
            "y": main_camera.original_position.y,
            "z": main_camera.original_position.z,
            "fov": main_camera.original_fov,
            "duration": final_args.duration
        }
        main_camera.move_to_custom(new_args)
    else:
        main_camera.move_to_custom(final_args)


## Reconnects the main camera when necessary and returns its saved camera values.
func _get_state() -> Dictionary:
    if main_camera == null:
        reconnect_cameras()

    if main_camera == null:
        return {}
    return main_camera._get_state()


## Passes saved camera values to the active camera, reconnecting it when necessary.
func relay_load(args: Dictionary):
    if main_camera == null:
        old_data = args.duplicate(true)
        return
    if args.has("info"):
        main_camera.load(args.info[save_name])


## Updates [code]old_data[/code] using [code]data.duplicate[/code]; sends [code]restored[/code]
## notifications. It pauses for [code]get_tree().create_timer(0.1).timeout[/code] before continuing.
func restore(data: Dictionary) -> void:
    CustomLogger.hint(self, self.restore, "is restoring data.", CustomLogger.LEVEL.MILD)
    old_data = data.duplicate(true)
    await get_tree().create_timer(0.1).timeout
    restored.emit()
