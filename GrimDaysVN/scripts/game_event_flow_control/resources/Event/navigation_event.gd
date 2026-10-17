# Editor configuration for GameEventNavigation.
@icon("res://GrimDays/assets/visuals/editor_icons/wooden-sign.svg")
extends GameEvent
class_name GameEventNavigation

## The specific scene file to load when this event triggers.
@export var starting_scene: PackedScene


## Starts the selected dialogue timeline; sets [code]Dialogic.paused[/code] to false.
func start() -> void:
    super()
    if starting_scene != null:
        var scene = starting_scene as PackedScene
        var path = scene.resource_path
        SceneManager.swap_scenes(self, SceneManager.get_tree().current_scene, path)
        return

    if timeline != null:
        Dialogic.start(timeline)
        Dialogic.paused = false
        return
    SceneManager.swap_scenes(
        self,
        SceneManager.get_tree().current_scene,
        Repositories.get_resource_path(RepositoryTypes.SCENES, "navigation_location")
    )
    return


## Runs the parent event’s finishing behavior unless the game is in the Other mode.
func finish() -> void:
    if GameManager.state == GameManagerStates.STATES.Other:
        return
    super()
