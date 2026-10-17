# Editor configuration for navigation_testing.
@tool
extends Node3D
## Location ID associated with this scene or map interaction.
@export_enum("A") var current_location: String:
    set(value):
        current_location = value


## When the node enters the scene, this function connects responses to
## [code]SystemAdministrators.ready[/code]; changes the current location through
## [code]SystemAdministrators[/code].
func _enter_tree() -> void:
    if SystemAdministrators.is_node_ready():
        SystemAdministrators.set_location(current_location)
    else:
        SystemAdministrators.ready.connect(update_location)


## Changes the current location through [code]SystemAdministrators[/code].
func update_location() -> void:
    SystemAdministrators.set_location(current_location)


## Supplies the editor with location-name suggestions for the relevant exported property.
func _validate_property(property: Dictionary) -> void:
    if property.name == "current_location":
        property.hint_string = build_hint_string()


## Builds a comma-separated list of location IDs for the editor's selection suggestions.
func build_hint_string() -> String:
    var string: String = ""
    for location in NavigationAdministrator.LOCATIONS:
        string += location
        string += ","
    return string
