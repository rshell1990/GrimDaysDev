# Editor configuration for navigation_tester.
@tool
extends Node3D
## Location resource used by the navigation test.
@export var location: NavigationLocation


## Creates the test location’s background and interaction objects.
func _ready() -> void:
    if location == null:
        return
    insert_background()
    insert_interactables()


## Adds [code]background[/code] as a child node.
func insert_background() -> void:
    var background: Node3D = location.background.instantiate()
    add_child(background)
    background.set_owner(self)


## Instantiate and add the interactable elements in the current location to the scene.
func insert_interactables() -> void:
    for interactable_object in location.interactables:
        var interaction_point: NavigationInteractable = interactable_object.instantiate()
        add_child(interaction_point)
        interaction_point.set_owner(self)
