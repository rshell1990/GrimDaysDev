# Editor configuration for NavigationLocation.
@tool
extends Resource
## Authored location information, including its ID, background and interaction scenes.
class_name NavigationLocation

## Readable name shown to the player.
@export_category("Identification Data")
@export var display_name: String
## Lookup ID used to find this entry in the relevant resource collection.
@export_custom(PROPERTY_HINT_ENUM_SUGGESTION, "") var id: StringName

## Scene template used to create background.
@export_category("Scene Data")
@export var background: PackedScene
## Scenes placed in front of the location background.
@export var foreground_objects: Array[PackedScene]
## Scenes for objects the player can interact with at this location.
@export var interactables: Array[PackedScene]


## Supplies the editor with location-name suggestions for the relevant exported property.
func _validate_property(property: Dictionary) -> void:
    if property.name == "id":
        property.hint_string = build_hint_string()


## Builds a comma-separated list of location IDs for the editor's selection suggestions.
func build_hint_string() -> String:
    var string: String = ""
    for location in NavigationAdministrator.LOCATIONS:
        string += location
        string += ","
    return string
