## Keeps the current location and dimension and restores them from saved state.
class_name NavigationDirector
extends Node

## Notification for restored.
signal restored
## Notification for location changed. Supplies [code]new_location[/code] to connected functions.
signal location_changed(new_location)
## Notification for dimension changed. Supplies [code]new_dimension[/code] to connected functions.
signal dimension_changed(new_dimension)

## ID of the current navigation location.
var location: StringName = &"NovarasChildhoodHomeLivingRoom"
## Current world/dimension choice used by navigation.
var dimension: NavigationAdministrator.DIMENSIONS = NavigationAdministrator.DIMENSIONS.PRIME
## Key used to identify this script’s data in saved state.
var save_name: String = "navigation"


## When the node enters the scene, this function registers [code]self[/code] with
## [code]SaveAndLoadSystemManager[/code].
func _enter_tree() -> void:
    SaveAndLoadSystemManager.add_node(self)


## When the node is ready, this function connects responses to [code]VNSignalBus.on_load[/code],
## [code]VNSignalBus.reset_sub_systems[/code].
func _ready() -> void:
    VNSignalBus.listen_for(location_changed, VNSignalBus.on_location_changed)
    VNSignalBus.listen_for(dimension_changed, VNSignalBus.on_dimension_changed)
    VNSignalBus.on_load.connect(_on_load)
    VNSignalBus.reset_sub_systems.connect(reset)


## Sets [code]location[/code] to [code]new_location[/code]; sends [code]location_changed[/code]
## notifications.
func set_location(new_location: StringName) -> void:
    CustomLogger.confirm(
        self, set_location, "Set location to: " + str(new_location), CustomLogger.LEVEL.MILD
    )
    location = new_location
    location_changed.emit(new_location)


## Updates the current navigation dimension and announces the change.
func set_dimension(new_dimension: NavigationAdministrator.DIMENSIONS) -> void:
    dimension = new_dimension
    dimension_changed.emit(new_dimension)


# TODO: Finish saving/loading for navigation director.
## Returns the current location ID and dimension for saving or restoration.
func _get_state() -> Dictionary:
    var data: Dictionary = {"location": location, "dimension": dimension}
    return data


## Sets [code]dimension[/code] to [code]data.info[save_name].dimension[/code].
func _on_load(data: Dictionary) -> void:
    CustomLogger.warn(
        self, self._on_load, "old on load method just triggered.", CustomLogger.LEVEL.SEVERE
    )
    set_location(data.info[save_name].location)
    dimension = data.info[save_name].dimension


## Changes the game mode through [code]GameManager[/code]; waits for a timer through
## [code]SystemHelpers[/code]; sets [code]dimension[/code] to [code]data.dimension[/code]. It also
## sends [code]restored[/code] notifications. It pauses for [code]SceneManager.load_complete[/code],
## [code]SystemHelpers.start_timer(VNAnimationTimes.NEAR_INSTANT)[/code] before continuing.
func restore(data: Dictionary) -> void:
    CustomLogger.hint(self, self.restore, "is restoring data.", CustomLogger.LEVEL.MILD)
    set_location(data.location)
    dimension = data.dimension
    if GameManager.state == GameManagerStates.STATES.Navigation:
        # Saved state is already coherent. Rebuild entry work explicitly after
        # restoring the location instead of relying on mismatched state IDs.
        GameManager.state_manager.restart_current_state()
        if SceneManager.swapping:
            await SceneManager.load_complete
    await SystemHelpers.start_timer(VNAnimationTimes.NEAR_INSTANT)
    restored.emit()


## Sets [code]location[/code] to [code]&"NovarasChildhoodHomeLivingRoom"[/code]; sets
## [code]dimension[/code] to [code]NavigationAdministrator.DIMENSIONS.PRIME[/code].
func reset() -> void:
    CustomLogger.warn(
        self,
        self.reset,
        " is resetting, location and dimension set to default.",
        CustomLogger.LEVEL.MILD
    )
    location = &"NovarasChildhoodHomeLivingRoom"
    dimension = NavigationAdministrator.DIMENSIONS.PRIME
