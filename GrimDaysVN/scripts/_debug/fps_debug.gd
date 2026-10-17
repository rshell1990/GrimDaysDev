extends LoadablePanel

## Shared fixed value for right position.
const RIGHT_POSITION: Vector2 = Vector2(1616, 102)
## Shared fixed value for left position.
const LEFT_POSITION: Vector2 = Vector2(30, 30)


## Positions the performance display on the right when the navigation overlay is visible, or on the
## left otherwise.
func _ready() -> void:
    if $"../Navigation Overlay Operator".visible:
        position = RIGHT_POSITION
    else:
        position = LEFT_POSITION


## Toggles the performance display when its configured input action is released.
func _input(event: InputEvent) -> void:
    if event.is_action_released("debug_toggle"):
        visible = !visible


## Moves the performance display to avoid the currently visible navigation overlay.
func _on_navigation_visibility_changed() -> void:
    if $"../Navigation Overlay Operator".visible:
        position = RIGHT_POSITION
    else:
        position = LEFT_POSITION
