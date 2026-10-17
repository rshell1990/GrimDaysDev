# Editor configuration for NavigationInteractableTransferScene.
@tool
@icon("res://GrimDays/assets/visuals/at-icons/node3d/door.svg")
extends NavigationInteractable
## Moves the player to a configured location when the interaction is clicked.
class_name NavigationInteractableTransferScene

## Location ID to enter when the player activates this travel interaction.
@export_custom(PROPERTY_HINT_ENUM_SUGGESTION, "") var leads_to: StringName


## When the node is ready, this function connects responses to [code]child.input_event[/code],
## [code]child.area_entered[/code].
func _ready() -> void:
    super()
    for child in get_children():
        if child is not Area3D:
            continue
        child.input_event.connect(validate_collision)
        if child.area_entered.is_connected(_on_area_3d_mouse_entered):
            continue
        child.area_entered.connect(_on_area_3d_mouse_entered)
        child.area_entered.connect(_on_area_3d_mouse_exited)


## Sends [code]activated[/code] notifications.
func validate_collision(_camera, event, _event_position, _normal, _shape_index) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        SystemHelpers.print(self.name, " collision detected.")
        activated.emit(leads_to)
        _on_area_3d_mouse_exited(area)


## Supplies the editor with location-name suggestions for the relevant exported property.
func _validate_property(property: Dictionary) -> void:
    if property.name == "leads_to":
        property.hint_string = MapInteractable.build_hint_string()
