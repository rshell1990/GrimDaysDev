extends Node
## CharacterSpriteTransfer controls the movement of characters between the various 'layers' that characters exist on the
## scene as children of.
class_name CharacterSpriteTransfer
## Notification for moving.
signal moving
## Notification for stopped.
signal stopped
## Character object controlled or observed by this helper.
var character: CharacterOperator
## Shared fixed value for upward movement.
const UPWARD_MOVEMENT: float = 3.0  #50.0
## Shared fixed value for end scale.
const END_SCALE: Vector3 = Vector3(0.2, 0.2, 0.2)
## Shared fixed value for steps.
const STEPS: int = 12


## When the node is ready, this function sets [code]character[/code] to
## [code]get_parent().get_parent()[/code].
func _ready():
    character = get_parent().get_parent()
    character.listen_for(moving, character.set_moving)
    character.listen_for(stopped, character.set_stopped)


## Use the data within the dictionary to
func execute(data: Dictionary) -> void:
    moving.emit()
    character.disable_collisions()
    var original_depth = character.get_parent()
    character.reparent(data.target_depth)
    var start = character.position
    var target = Vector3(data.target_location.x, 0, 0)
    CustomLogger.hint(self, execute, "Start: " + str(start) + " - Target: " + str(target), CustomLogger.LEVEL.MILD)

    var initial_scale: Vector3 = character.scale

    # var reparented_scale:Vector3 = character.scale

    var target_origin := Vector3(target.x, target.y, target.z)
    var travel_points: Array[Vector3] = create_target_points(start, target, target_origin)
    var scale_points: Array[Vector3] = create_scale_points(initial_scale, END_SCALE)

    if original_depth.start_hidden:
        var tween = SystemHelpers.create_tween()
        tween.tween_property(character, "modulate:a", 1.0, VNAnimationTimes.STANDARD)

    for x in range(0, travel_points.size()):
        tween_to_scale(scale_points[x])
        await tween_to_position(travel_points[x])

    stopped.emit()

    if data.target_depth.start_hidden:
        var tween = SystemHelpers.create_tween()
        await tween.tween_property(character, "modulate:a", 0.0, VNAnimationTimes.STANDARD).finished

    character.enable_collisions()
    character.layers = data.target_depth.layers
    character.sorting_offset = data.target_depth.sorting_offset


## Returns intermediate scale values from the starting size to the target size.
func create_scale_points(start: Vector3, target: Vector3) -> Array[Vector3]:
    var steps: int = STEPS
    var scale_points: Array[Vector3] = []
    for x in range(1, steps):
        var intermediate_point: Vector3 = Vector3(
            lerpf(start.x, target.x, float(x) / steps),
            lerpf(start.y, target.y, float(x) / steps),
            lerpf(start.z, target.z, float(x) / steps)
        )
        scale_points.append(intermediate_point)

    scale_points.append(END_SCALE)
    return scale_points


## Returns intermediate positions for transferring a character between display layers.
func create_target_points(start: Vector3, target: Vector3, target_origin: Vector3) -> Array[Vector3]:
    var steps: int = STEPS
    var travel_points: Array[Vector3] = []
    for x in range(1, steps):
        var adjustment: float = UPWARD_MOVEMENT * 2.0
        if start.y != target.y:
            adjustment = SystemHelpers.halff(adjustment)
        if SystemHelpers.is_even(x):
            travel_points.append(
                Vector3(
                    lerpf(start.x, target.x, float(x) / steps),
                    lerpf(start.y, target.y + adjustment, float(x) / steps),
                    lerpf(start.z, target.z, float(x) / steps)
                )
            )
        else:
            travel_points.append(
                Vector3(
                    lerpf(start.x, target.x, float(x) / steps),
                    lerpf(start.y, target.y - adjustment, float(x) / steps),
                    lerpf(start.z, target.z, float(x) / steps)
                )
            )

    travel_points.append(target_origin)
    return travel_points


## Animates the character through the supplied position points.
func tween_to_position(points) -> void:
    var tween = create_tween()
    await tween.tween_property(character, "position", points, 0.1).finished


## Animates the character through the supplied scale values.
func tween_to_scale(points) -> void:
    var tween = create_tween()
    tween.tween_property(character, "scale", points, 0.1)


## Moves the character under its destination layer during the transfer.
func reparent_character(supplied_character, data: Dictionary) -> void:
    UIDirector.fade_flag_show()
    await SystemHelpers.start_timer(VNAnimationTimes.NEAR_INSTANT)
    supplied_character.reparent(data.target_depth)
    await UIDirector.fade_flag_hide()
