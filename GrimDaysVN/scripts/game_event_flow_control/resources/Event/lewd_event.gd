extends GameEventSequence
class_name GameEventLewd

@export_category("Event Replay")
## The specific character associated with this event, will be used to filter events.
@export var scenario_character: Common.NAMES
## A thumbnail to represent the scene for the replay system.
@export var thumbnail: Texture2D


## Sets the event’s scenario type to Lewd when created.
func _init() -> void:
    scenario_type = SCENARIO_TYPES.Lewd


## Replaces the current scene with this event's configured starting scene.
func start() -> void:
    var scene = starting_scene as PackedScene
    var path = scene.resource_path
    SceneManager.swap_scenes(self, SceneManager.get_tree().current_scene, path)
    return
