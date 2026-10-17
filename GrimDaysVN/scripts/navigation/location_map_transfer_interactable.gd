# Editor configuration for MapInteractable.
@tool
extends NavigationInteractable
## Map interaction that requests a location change and provides editor location suggestions.
class_name MapInteractable

## Notification for location change. Supplies [code]new_location[/code] to connected functions.
signal location_change(new_location: StringName)

## Location ID associated with this scene or map interaction.
@export_custom(PROPERTY_HINT_ENUM_SUGGESTION, "PrimeMap,DarkMap") var current_location: StringName
## Location ID to enter when the player activates this travel interaction.
@export_custom(PROPERTY_HINT_ENUM_SUGGESTION, "")
var leads_to: StringName = NavigationAdministrator.LOCATIONS[0]

## Story event most recently supplied to this scene.
var found_event: GameEvent


## Runs parent setup and connects location-change requests to the shared navigation notification.
func _ready() -> void:
    super()
    VNSignalBus.listen_for(location_change, VNSignalBus.on_location_changed)


## Changes the current location through [code]SystemAdministrators[/code]; sends
## [code]VNSignalBus.event_found[/code], [code]VNSignalBus.on_tooltip_hide[/code] notifications. It
## pauses for [code]get_tree().create_timer(VNAnimationTimes.NEAR_INSTANT).timeout[/code] before
## continuing.
func _input(event: InputEvent) -> void:
    if not active:
        return

    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        await get_tree().create_timer(VNAnimationTimes.NEAR_INSTANT).timeout
        var game_event = SystemAdministrators.check_for_event(leads_to)
        #SystemHelpers.print(game_event)
        if game_event != null:
            if not game_event.blocks_swap:
                SystemAdministrators.set_location(leads_to)
            VNSignalBus.event_found.emit(game_event)
            return
        SystemAdministrators.set_location(leads_to)
        VNSignalBus.on_tooltip_hide.emit()
        SceneManager.swap_scenes(
            self,
            SceneManager.get_tree().current_scene,
            Repositories.get_resource_path(RepositoryTypes.SCENES, "navigation_location")
        )


## Supplies the editor with location-name suggestions for the relevant exported property.
func _validate_property(property: Dictionary) -> void:
    if property.name == "leads_to":
        property.hint_string = build_hint_string()


## Builds a comma-separated list of location IDs for the editor's selection suggestions.
static func build_hint_string() -> String:
    var string: String = ""
    for location in NavigationAdministrator.LOCATIONS:
        string += location
        string += ","
    return string
