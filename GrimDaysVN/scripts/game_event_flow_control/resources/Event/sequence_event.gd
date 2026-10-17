# Editor configuration for GameEventSequence.
@icon("res://GrimDays/assets/visuals/editor_icons/oak.svg")
extends GameEvent
class_name GameEventSequence

## The specific scene file to load when this event triggers.
@export var starting_scene: PackedScene
## The next event in a chain/sequence.
@export var finished_event: GameEvent


## Sets the event’s scenario type to Sequence when created.
func _init() -> void:
    scenario_type = SCENARIO_TYPES.Sequence


## Continues in place when swapping is blocked; otherwise loads the event's scene.
func start() -> void:
    if blocks_swap:
        super()
        return
    if starting_scene != null:
        var scene = starting_scene as PackedScene
        var path = scene.resource_path
        GameManager.change_state(GameManagerStates.STATES.ScenarioSequence)
        SceneManager.swap_scenes(self, SceneManager.get_tree().current_scene, path)
        return

    GameManager.change_state(GameManagerStates.STATES.Scenario)
    SceneManager.swap_scenes(
        self,
        SceneManager.get_tree().current_scene,
        Repositories.get_resource_path(RepositoryTypes.SCENES, "portraited_scene")
    )
    return


## Sends [code]VNSignalBus.event_found[/code] notifications. It pauses for
## [code]SystemHelpers.get_game_root().get_tree().create_timer(VNAnimationTimes.NEAR_INSTANT).timeout[/code]
## before continuing.
func finish() -> void:
    super()
    if GameManager.state == GameManagerStates.STATES.Other:
        return
    if finished_event == null:
        return
    await SystemHelpers.get_game_root().get_tree().create_timer(VNAnimationTimes.NEAR_INSTANT).timeout
    VNSignalBus.event_found.emit(finished_event)
