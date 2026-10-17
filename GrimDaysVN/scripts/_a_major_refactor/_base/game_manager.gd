#region GAME MANGER
#class_name GameSystemManager
extends PersistentSystemManager
#endregion
## Notification for state changed. Supplies [code]new_state[/code] to connected functions.
signal state_changed(new_state)
## Notification for world stage changed.
signal world_stage_changed
## Scene node used for state manager, found when this node is ready.
@onready var state_manager: GameManagerStates = $States
## Key used to identify this script’s data in saved state.
var save_name: String = "game_manager"
## Previous game mode, used to decide which behavior and input are active.
var last_state: GameManagerStates.STATES = GameManagerStates.STATES.BeforeGame
## Current game mode, used to decide which behavior and input are active.
var state: GameManagerStates.STATES = GameManagerStates.STATES.BeforeGame
## Story-progress number used by events and requirements to decide what is available.
var world_stage: int = 0
## Time value used when calculating elapsed play time; see the update and conversion functions in
## this script.
var time_passed: int = 0
## IDs of story events already encountered, used when checking event requirements and repeats.
var seen_events: Array[StringName]
## Story event currently being handled by the game manager.
var current_event: GameEvent
## Whether a previously seen scene or event is being replayed.
var in_replay: bool
## Whether the title screen has already been shown.
var saw_title: bool = false
## Scene whose processing was paused and may need to be restored later.
var paused_scene: Node


## Returns the game manager's story-progress, event and mode values for restoration, including the
## last outgoing scene path.
func _get_state() -> Dictionary:
    var data: Dictionary = {
        "world": world_stage,
        "seen_events": seen_events,
        "current_event": current_event.id if current_event != null else &"",
        "state": state,
        "last_state": last_state,
        "last_swapped_scene": SceneManager.last_swapped_scene
    }
    return data


## Chooses between rebuilding the saved event's scene and restoring a checkpoint in the current
## event, based on the saved event ID.
func restore(data: Dictionary) -> void:
    CustomLogger.hint(self, self.restore, "is restoring data.", CustomLogger.LEVEL.MILD)
    if not current_event or data.current_event != current_event.id:
        full_load(data)
    else:
        restore_from_checkpoint(data)


## Sets [code]world_stage[/code] to [code]data.world[/code]; sets [code]seen_events[/code] to
## [code]data.seen_events[/code]; sets [code]last_state[/code] to [code]data.last_state[/code]. It
## also sends [code]restored[/code] notifications. It pauses for
## [code]SceneManager.load_complete[/code], [code]get_tree().create_timer(0.1).timeout[/code] before
## continuing.
func full_load(data: Dictionary) -> void:
    world_stage = data.world
    if data.has("seen_events"):
        seen_events = data.seen_events

    var saved_event = data.current_event
    print_rich("[bgcolor=#F33][b][color=#000]Stored event is: (", saved_event, ")")
    last_state = data.last_state

    if saved_event == "test_2_over":
        saved_event = ""
    if not saved_event.is_empty():
        current_event = SystemAdministrators.find_event_by_id(saved_event)
    else:
        if data.state == GameManagerStates.STATES.ScenarioSequence:
            current_event = SystemAdministrators.find_event_by_id(data.seen_events[-1])
        else:
            current_event = null

    if current_event:
        match current_event.scenario_type:
            GameEvent.SCENARIO_TYPES.Normal:
                SceneManager.swap_scenes(
                    self,
                    get_tree().current_scene,
                    Repositories.get_resource_path(RepositoryTypes.SCENES, "portraited_scene")
                )
            GameEvent.SCENARIO_TYPES.Lewd:
                pass
            GameEvent.SCENARIO_TYPES.Sequence:
                var sequence_event: GameEventSequence = current_event as GameEventSequence
                @warning_ignore("incompatible_ternary")
                var scene_to_swap: String = (
                    sequence_event.starting_scene.resource_path if sequence_event.starting_scene else ""
                )
                SceneManager.swap_scenes(
                    self,
                    get_tree().current_scene,
                    (
                        scene_to_swap
                        if not scene_to_swap.is_empty()
                        else Repositories.get_resource_path(RepositoryTypes.SCENES, "portraited_scene")
                    )
                )
            GameEvent.SCENARIO_TYPES.Battle:
                pass

    if SceneManager.swapping:
        await SceneManager.load_complete
        var current_scene = get_tree().current_scene
        current_scene.process_mode = Node.PROCESS_MODE_DISABLED
        paused_scene = current_scene
    state = data.state

    await get_tree().create_timer(0.1).timeout
    restored.emit()


## Currently performs no work; this function is a placeholder for behavior supplied later or by a
## child script.
func restore_from_checkpoint(data: Dictionary) -> void:
    pass
