extends Node3D
## Updates the exploration scene when its location or current event changes.
class_name NavigationOperator
#region SIGNALS / VARS
## Signals that the navigation operator has been intialized.
signal intialized_scene
## Signals that the necessary data to start a battle is stored in the current scene.
signal ready_for_battle
## Data received from the last active scene.
var given_data: Dictionary
## The resource template for the current location.
var current_location_resource: NavigationLocation
## The identifier for the current location.
var location_id: StringName
## When a game event is found, store it to pass to the next scene loaded.
var found_event: GameEvent
## The node that becomes the parent for the background scene for the current location.
@export var background_holder: Node3D
## The node that becomes the parent for the interactable elements of the current location.
@export var interactable_holder: Node3D
#endregion


#region ON INIT
## Instantiate and add the background in the current location to the scene.
func insert_background() -> void:
    var background: Node3D = current_location_resource.background.instantiate()
    background_holder.add_child(background)
    background.set_owner(background_holder)


## Instantiate and add the interactable elements in the current location to the scene.
func insert_interactables() -> void:
    for interactable_object in current_location_resource.interactables:
        var interaction_point: NavigationInteractable = interactable_object.instantiate()
        interactable_holder.add_child(interaction_point)
        interaction_point.set_owner(interactable_holder)
        interaction_point.activated.connect(on_interactable_activated)
        if not interaction_point.get_is_visible():
            interaction_point.queue_free()


#endregion


## When the node enters the scene, this function connects responses to
## [code]VNSignalBus.event_found[/code], [code]VNSignalBus.location_changed[/code].
func _enter_tree() -> void:
    VNSignalBus.event_found.connect(on_event_found)
    VNSignalBus.location_changed.connect(on_location_changed)
    CustomLogger.hint(self, _enter_tree, "Entered tree.", CustomLogger.LEVEL.MILD)


## Schedules [code]bg[/code] for deletion; schedules [code]interactable[/code] for deletion; updates
## [code]current_location_resource[/code] using [code]Repositories.get_info[/code].
func on_location_changed(new_location: StringName) -> void:
    if current_location_resource:
        if current_location_resource.id == new_location:
            CustomLogger.warn(
                self,
                on_location_changed,
                " same location... aborting.",
                CustomLogger.LEVEL.VERBOSE
            )
            return
        if new_location == "PrimeMap":
            CustomLogger.confirm(
                self,
                on_location_changed,
                " map operator will become active, this scene is about to leave."
            )
            return
    current_location_resource = Repositories.get_info(RepositoryTypes.LOCATIONS, new_location)

    assert(current_location_resource)

    CustomLogger.hint(
        self,
        on_location_changed,
        "Cleaning background and interactable holders, then inserting current content."
    )
    for bg in background_holder.get_children():
        bg.queue_free()
    for interactable in interactable_holder.get_children():
        interactable.queue_free()

    insert_background()
    insert_interactables()


## When the node is ready, this function updates [code]location_id[/code] using
## [code]SystemAdministrators.current_location[/code].
func _ready() -> void:
    location_id = SystemAdministrators.current_location()


## Sets [code]found_event[/code] to [code]game_event[/code].
func on_event_found(game_event) -> void:
    CustomLogger.hint(self, self.on_event_found, "Storing emitted game_event: " + game_event.id, 2)
    found_event = game_event


#region INTERACT ACTIVATED
## When an interactable object is selected from the navigation operator, check for a game event,
## or transfer to a new location.
func on_interactable_activated(new_location: String) -> void:
    if Dialogic.current_timeline != null:
        CustomLogger.warn(
            self,
            on_interactable_activated,
            "Timeline currently active, aborting call to transfer to a new location.",
            2
        )
        return
    var game_event = SystemAdministrators.check_for_event(new_location)

    if not game_event:
        CustomLogger.confirm(
            self,
            on_interactable_activated,
            "No event found after transfer activated, proceeding to change location.",
            2
        )
        UIDirector.fade_flag_show()
        SystemAdministrators.set_location(new_location)
        var scene_path = Repositories.get_resource_path(
            RepositoryTypes.SCENES, "navigation_location"
        )
        SceneManager.swap_scenes(self, self, scene_path)
        return

    if not game_event.blocks_swap:
        SystemAdministrators.set_location(new_location)
    CustomLogger.hint(
        self,
        on_interactable_activated,
        "Emitting found event: " + str(game_event),
        2
    )
    VNSignalBus.event_found.emit(game_event)


#region SCENE MANAGEMENT
## Setup the scene, before starting it.
func init_scene() -> void:
    Input.set_custom_mouse_cursor(null)
    current_location_resource = Repositories.get_info(RepositoryTypes.LOCATIONS, location_id)

    CustomLogger.hint(
        self,
        self.init_scene,
        "Inserting Background and Interactables: ",
        CustomLogger.LEVEL.MILD
    )
    insert_background()
    insert_interactables()

    CustomLogger.confirm(self, self.init_scene, " emitting initialized.", 2)
    intialized_scene.emit(self)


## After init, make this scene available.
func start_scene() -> void:
    CustomLogger.confirm(self, self.start_scene, "is starting.", 4)
    UIDirector.show_navigation()
    UIDirector.fade_flag_hide()


## Recieve data from the last scene.
func get_data_from_last_scene(data) -> void:
    CustomLogger.confirm(self, self.get_data_from_last_scene, "receive's data.", 3)
    given_data = data


## Before the current scene becomes inactive, pass this data to the next scene.
func pass_data_to_next_scene() -> Dictionary:
    var data: Dictionary = {"found_event": found_event}
    return data
#endregion
