extends Node
## Builds and animates a running path between character positions.
class_name CharacterSpriteRunTo
## Notification for moving.
signal moving
## Notification for stopped.
signal stopped

## Shared fixed value for upward movement.
const UPWARD_MOVEMENT: float = 3.0  #40.0
## Shared fixed value for downward movement.
const DOWNWARD_MOVEMENT: float = 2.0  #15.0
## Shared fixed value for horizontal movement.
const HORIZONTAL_MOVEMENT: int = 30
## Character object controlled or observed by this helper.
var character: CharacterOperator


## When the node is ready, this function sets [code]character[/code] to
## [code]get_parent().get_parent()[/code].
func _ready():
    character = get_parent().get_parent()
    character.listen_for(moving, character.set_moving)
    character.listen_for(stopped, character.set_stopped)


## Moves horizontally without changing depth or height; reports one moving/stopped pair.
## The character director owns dialogue pause state across concurrent movements.
func execute(data) -> void:
    var start: Vector3 = Vector3(data.current_position.x, data.current_position.y, data.current_position.z)
    var target_origin: Vector3 = Vector3(data.target_x, start.y, start.z)
    var travel_points: Array[Vector3] = create_travel_points(start, target_origin)

    moving.emit()
    for i in range(0, travel_points.size()):
        await tween_between_points(i, travel_points[i])

    stopped.emit()


## Returns intermediate positions used to animate the character's path from start to target.
func create_travel_points(start, target) -> Array[Vector3]:
    var travel_points: Array[Vector3] = []
    var steps: int = ceil((abs(target.x - start.x)) / HORIZONTAL_MOVEMENT)
    for x in range(1, steps):
        if x % 2 == 0:
            travel_points.append(
                Vector3(lerpf(start.x, target.x, float(x) / steps), start.y + UPWARD_MOVEMENT, start.z)
            )
        else:
            travel_points.append(
                Vector3(lerpf(start.x, target.x, float(x) / steps), start.y - DOWNWARD_MOVEMENT, start.z)
            )

    travel_points.append(target)
    return travel_points


## Animates the character between the supplied travel points.
func tween_between_points(i, point) -> void:
    var tween = create_tween()
    if i % 2 == 0:
        tween.set_ease(Tween.EASE_OUT)
    else:
        tween.set_ease(Tween.EASE_IN)
    await tween.tween_property(character, "position", point, 0.1).finished
