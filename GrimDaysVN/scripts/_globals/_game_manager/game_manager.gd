#region GAME MANAGER
extends Node
##
##
##

## Tracks the active story event, game mode and story progress, and restores those values when
## loading.
class_name GameManagerSingleton
#endregion
#region SIGNALS
## Notification for restored.
signal restored
## Notification for state changed. Supplies [code]new_state[/code] to connected functions.
signal state_changed(new_state)
## Notification for world stage changed.
signal world_stage_changed

#endregion
#region ON READY VARIABLES
## Scene node used for state manager, found when this node is ready.
@onready var state_manager: GameManagerStates = $States
#endregion

#region VARIABLES
## Whether the title screen has already been shown.
var saw_title: bool = false
## Key used to identify this script’s data in saved state.
var save_name: String = "game_manager"
## Previous game mode, used to decide which behavior and input are active.
var last_state: GameManagerStates.STATES = GameManagerStates.STATES.BeforeGame:
    get:
        var manager := get_node_or_null("States") as GameManagerStates
        if manager and manager.last_state:
            return manager.last_state.id
        return GameManagerStates.STATES.BeforeGame
    set(value):
        var manager := get_node_or_null("States") as GameManagerStates
        if manager and manager.states.has(value):
            manager.last_state = manager.states[value]
## Current game mode, used to decide which behavior and input are active.
var state: GameManagerStates.STATES = GameManagerStates.STATES.BeforeGame:
    get:
        var manager := get_node_or_null("States") as GameManagerStates
        if manager and manager.current_state:
            return manager.current_state.id
        return GameManagerStates.STATES.BeforeGame
    set(value):
        # Legacy assignments restore a coherent pair without replaying scene entry.
        var manager := get_node_or_null("States") as GameManagerStates
        if manager:
            manager.restore_state(value, last_state)
## Story-progress number used by events and requirements to decide what is available.
var world_stage: int = 0
## Playtime carried forward from the last full save load.
var accumulated_playtime_ms: int = 0
## IDs of story events already encountered, used when checking event requirements and repeats.
var seen_events: Array[StringName]
## Story event currently being handled by the game manager.
var current_event: GameEvent:
    get:
        return current_event
    set(value):
        CustomLogger.confirm(
            self,
            self.set,
            "Set current event to: " + str(value.id if value else &"null"),
            CustomLogger.LEVEL.VERY_VERBOSE
        )
        current_event = value
## Whether a previously seen scene or event is being replayed.
var in_replay: bool
## Engine ticks when the current playtime session began.
var session_started_at_ms: int = Time.get_ticks_msec()
## Scene whose processing was paused and may need to be restored later.
var paused_scene: Node
## Whether a dialogue timeline is currently marked as running.
var timeline_active: bool
## Time value used when calculating elapsed play time; see the update and conversion functions in
## this script.
var program_start: float
#endregion

#region PROPERTIES
## Elapsed play time expressed in seconds.
var seconds_passed:
    get():
        return get_total_playtime_ms() / 1000

## Elapsed play time expressed in minutes.
var minutes_passed:
    get():
        return seconds_passed / 60

## Elapsed play time expressed in hours.
var hours_passed:
    get():
        return minutes_passed / 60


## Returns elapsed play time as hours:minutes:seconds. Values are not padded with leading zeroes.
func get_time_played() -> String:
    var seconds: int = seconds_passed
    var minutes: int = minutes_passed
    var hours: int = hours_passed

    seconds -= minutes * 60
    minutes -= hours * 60

    return str(hours) + ":" + str(minutes) + ":" + str(seconds)


#endregion

#region SIGNAL RESPONSES
## Counter used to tell whether a newer event replaced the one a waiting callback was handling.
var _event_generation: int = 0


## Remembers the new event and updates the connection used to handle its finishing dialogue
## timeline.
func _on_event_found(event: GameEvent) -> void:
    _event_generation += 1
    set_deferred("current_event", event)
    if not event.finishing_timeline:
        CustomLogger.hint(
            self,
            self._on_event_found,
            (
                "[color=#5F0]" + name + " Event missing finishing timeline..."
                + str(event.finishing_timeline)
            ),
            CustomLogger.LEVEL.MILD
        )
        if Dialogic.timeline_ending.is_connected(on_timeline_ending):
            Dialogic.timeline_ending.disconnect(on_timeline_ending)
        return
    if not Dialogic.timeline_ending.is_connected(on_timeline_ending):
        CustomLogger.hint(
            self,
            self._on_event_found,
            "[color=#5F0]" + name + " is reconnecting to timeline end.[/color]",
            CustomLogger.LEVEL.VERY_VERBOSE
        )
        Dialogic.timeline_ending.connect(on_timeline_ending)
    CustomLogger.confirm(
        self,
        self._on_event_found,
        "has handled " + str(event.id),
        CustomLogger.LEVEL.VERY_VERBOSE
    )


## Marks the dialogue timeline as active.
func on_timeline_starting() -> void:
    timeline_active = true


## Handles the end of the current event's dialogue, waiting for timeline completion and ignoring
## callbacks belonging to an event that has been replaced.
func on_timeline_ending(timeline) -> void:
    if not timeline:
        CustomLogger.warn(
            self,
            self.on_timeline_ending,
            "No timeline to handle...",
            CustomLogger.LEVEL.MILD
        )
        return
    timeline_active = false
    @warning_ignore("incompatible_ternary")
    CustomLogger.hint(
        self,
        self.on_timeline_ending,
        (
            (
                "[color=#5F0]"
                + name
                + " is evaluating"
                + timeline.to_string()
                + " ending... starting evaluation by GameManager... Current event:"
                + current_event.id
            )
            if current_event
            else "null"
        ),
        CustomLogger.LEVEL.VERY_VERBOSE
    )
    if current_event == null and state != GameManagerStates.STATES.Navigation:
        current_event = Repositories.get_info(RepositoryTypes.EVENTS, seen_events[-1])
    if timeline and current_event and timeline != current_event.finishing_timeline:
        CustomLogger.warn(
            self,
            self.on_timeline_ending,
            (
                str(timeline)
                + "- does not match -"
                + str(current_event.finishing_timeline)
                + " and thus will abort..."
            ),
            CustomLogger.LEVEL.MILD
        )
        return
    if in_replay:
        SceneManager.swap_scenes(
            self,
            SceneManager.get_tree().current_scene,
            SceneManager.last_swapped_scene
        )
        return
    if GameManager.state == GameManagerStates.STATES.Other:
        return
    if not current_event:
        CustomLogger.warn(
            self,
            self.on_timeline_ending,
            "No event to handle...",
            CustomLogger.LEVEL.VERBOSE
        )
        return
    CustomLogger.confirm(
        self,
        self.on_timeline_ending,
        current_event.id + " handled by GameManager on timeline\n"
        + timeline.to_string() + " ending...",
        CustomLogger.LEVEL.VERY_VERBOSE
    )
    var ending_event: GameEvent = current_event
    var ending_generation := _event_generation
    if Dialogic.current_timeline:
        await Dialogic.timeline_ended
    # A final timeline instruction may already have requested its next event.
    # Never finish that replacement event or clear it from under the battle.
    if current_event != ending_event or ending_generation != _event_generation:
        return
    ending_event.finish()
    if (not timeline_active and current_event == ending_event
            and ending_generation == _event_generation):
        current_event = null


## Enters TimeChanging only for an actual time change outside loading or saved-state restoration.
func _on_time_change(old_time: TimeAdministrator.TIMES, _new_time: TimeAdministrator.TIMES) -> void:
    if (old_time == _new_time
            or state == GameManagerStates.STATES.Loading
            or SaveAndLoadSystemManager.restoring_data):
        return
    state_manager.states[GameManagerStates.STATES.TimeChanging].start_time = old_time
    change_state(GameManagerStates.STATES.TimeChanging)


#region PROCESS
## Returns saved playtime plus elapsed milliseconds since this session began.
func get_total_playtime_ms() -> int:
    return accumulated_playtime_ms + Time.get_ticks_msec() - session_started_at_ms


#endregion


#region MAIN
## Accepts a world-stage number that is at least the current value, then announces the update. Lower
## values are ignored.
func update_world_stage(new_stage: int) -> void:
    if new_stage < world_stage:
        return
    world_stage = new_stage
    world_stage_changed.emit()


## Requests a serialized transition. State IDs are views of the manager's nodes.
func change_state(new_state: GameManagerStates.STATES) -> void:
    state_manager.change_state(new_state)


## Forward only committed transitions; listeners always see matching node and ID.
func _on_state_committed(new_state: GameManagerStates.STATES) -> void:
    state_changed.emit(new_state)


## Resume the previous state without replaying its entry actions.
func restore_last_state_on_end() -> void:
    state_manager.restore_last_state_on_end()


## Resume the previous state and rerun its entry actions.
func restart_last_state_on_end() -> void:
    state_manager.restart_last_state_on_end()


## Restarts the current event through its scene and timeline setup.
func restart_event() -> void:
    CustomLogger.hint(
        self,
        self.restart_event,
        "[color=#F50]Restarting current event: " + current_event.id + "[/color]",
        CustomLogger.LEVEL.MILD
    )

    UIDirector.cover_screen()
    VNSignalBus.clear_rollback.emit()
    await get_tree().create_timer(VNAnimationTimes.LONG).timeout
    get_tree().reload_current_scene()
    await get_tree().create_timer(VNAnimationTimes.LONG).timeout
    UIDirector.reveal_screen()
    if current_event == null:
        return
    VNSignalBus.event_found.emit(current_event)


## Reconnects the game manager to the dialogue timeline's ending notification.
func reconnect_to_timeline_end() -> void:
    if not Dialogic.timeline_ending.is_connected(on_timeline_ending):
        CustomLogger.hint(
            self,
            self.reconnect_to_timeline_end,
            "[b][i][color=#F7C] is reconnecting to the current timeline ending.[/color][/i][/b]",
            CustomLogger.LEVEL.MILD
        )
        Dialogic.timeline_ending.connect(on_timeline_ending)


## Disconnects the current timeline-ending listener before a loading sequence can replace the event.
func on_loading_sequence_start() -> void:
    if Dialogic.timeline_ending.is_connected(on_timeline_ending):
        CustomLogger.hint(
            self,
            on_loading_sequence_start,
            "[b][i][color=#F55] is disconnected from the timeline ending.[/color][/i][/b]",
            CustomLogger.LEVEL.MILD
        )
        Dialogic.timeline_ending.disconnect(on_timeline_ending)


## Uses loaded event information to restore the event/scene relationship expected by the game
## manager.
func handle_loading_event(data: Dictionary) -> void:
    var saved_event = data.info[save_name].current_event
    if saved_event == "test_2_over":
        saved_event = ""
    if saved_event.is_empty():
        return
    current_event = SystemAdministrators.find_event_by_id(saved_event)


#region HOUSEKEEPING
## When the node enters the scene, this function registers [code]self[/code] with
## [code]SaveAndLoadSystemManager[/code]; updates [code]program_start[/code] using
## [code]Time.get_unix_time_from_system[/code].
func _enter_tree() -> void:
    SaveAndLoadSystemManager.add_node(self)
    program_start = Time.get_unix_time_from_system()


## When the node is ready, this function connects responses to
## [code]VNSignalBus.reset_sub_systems[/code], [code]VNSignalBus.time_passed[/code],
## [code]VNSignalBus.event_found[/code] and committed state transitions.
func _ready() -> void:
    VNSignalBus.listen_for(state_changed, VNSignalBus.on_state_change)
    VNSignalBus.reset_sub_systems.connect(reset)
    VNSignalBus.time_passed.connect(_on_time_change)
    VNSignalBus.event_found.connect(_on_event_found)
    state_manager.transitioned.connect(_on_state_committed)
    VNSignalBus.loading_sequence_start.connect(on_loading_sequence_start)
    Dialogic.timeline_started.connect(on_timeline_starting)
    change_state(state)


#endregion
#region SAVE / LOAD
## Starts a new playtime session and clears story progress.
func reset() -> void:
    CustomLogger.hint(self, self.reset, "is resetting.", CustomLogger.LEVEL.MILD)
    accumulated_playtime_ms = 0
    session_started_at_ms = Time.get_ticks_msec()
    seen_events = []
    current_event = null
    in_replay = false
    world_stage = 0
    last_state = GameManagerStates.STATES.BeforeGame
    timeline_active = false
    paused_scene = null


## Returns the game manager's story-progress, event and mode values for restoration, including the
## last outgoing scene path.
func _get_state() -> Dictionary:
    var data: Dictionary = {
        "world": world_stage,
        "seen_events": seen_events,
        "current_event": current_event.id if current_event != null else &"",
        "time": get_total_playtime_ms(),
        "state": state,
        "last_state": last_state,
        "last_swapped_scene": SceneManager.last_swapped_scene,
        "timeline_active": timeline_active
    }
    return data


## Chooses between rebuilding the saved event's scene and restoring a checkpoint in the current
## event, based on the saved event ID.
func restore(data: Dictionary) -> void:
    CustomLogger.hint(self, self.restore, "is restoring data.", CustomLogger.LEVEL.MILD)
    var saved_event = data.current_event
    CustomLogger.hint(
        self, self.restore, "Stored event is: (" + saved_event + ")", CustomLogger.LEVEL.MILD
    )

    if saved_event.is_empty():
        if data.state in [
            GameManagerStates.STATES.ScenarioSequence, GameManagerStates.STATES.Scenario
        ]:
            saved_event = data.seen_events[-1]

    if current_event and saved_event == current_event.id:
        restore_from_checkpoint(data)
    elif not current_event or data.current_event != current_event.id:
        full_load(data)
    else:
        restore_from_checkpoint(data)


## Sets [code]world_stage[/code] to [code]data.world[/code]; sets
## [code]accumulated_playtime_ms[/code] to [code]data.time[/code]; sets [code]seen_events[/code]
## to [code]data.seen_events[/code]. It also sends [code]restored[/code] notifications. It pauses
## for [code]SceneManager.load_complete[/code],
## [code]get_tree().create_timer(0.1).timeout[/code] before continuing.
func full_load(data: Dictionary) -> void:
    CustomLogger.hint(
        self,
        self.full_load,
        "[color=#0F0]GameManager performing full load[/color]",
        CustomLogger.LEVEL.MILD
    )
    world_stage = data.world
    accumulated_playtime_ms = data.time
    session_started_at_ms = Time.get_ticks_msec()
    if data.has("seen_events"):
        seen_events = data.seen_events
    if data.has("timeline_active"):
        timeline_active = data.timeline_active

    var saved_event = data.current_event
    last_state = data.last_state

    if not saved_event.is_empty():
        current_event = SystemAdministrators.find_event_by_id(saved_event)
    else:
        if (
            data.state in [
                GameManagerStates.STATES.ScenarioSequence, GameManagerStates.STATES.Scenario
            ]
            or (data.has("timeline_active") and timeline_active)
        ):
            current_event = SystemAdministrators.find_event_by_id(data.seen_events[-1])
        else:
            current_event = null

    if current_event:
        CustomLogger.hint(
            self,
            self.full_load,
            "Current event is: (" + current_event.id + ")",
            CustomLogger.LEVEL.MILD
        )
        match current_event.scenario_type:
            GameEvent.SCENARIO_TYPES.Normal:
                change_state(GameManagerStates.STATES.Scenario)
                SceneManager.swap_scenes(
                    self,
                    get_tree().current_scene,
                    Repositories.get_resource_path(RepositoryTypes.SCENES, "portraited_scene")
                )
            GameEvent.SCENARIO_TYPES.Navigation:
                if current_event is GameEventSequence:
                    change_state(GameManagerStates.STATES.Scenario)
                    SceneManager.swap_scenes(
                        self,
                        SceneManager.get_tree().current_scene,
                        Repositories.get_resource_path(RepositoryTypes.SCENES, "portraited_scene")
                    )
            GameEvent.SCENARIO_TYPES.Lewd:
                pass
            GameEvent.SCENARIO_TYPES.Sequence:
                change_state(GameManagerStates.STATES.ScenarioSequence)
                var sequence_event: GameEventSequence = current_event as GameEventSequence
                @warning_ignore("incompatible_ternary")
                var scene_to_swap: String = (
                    sequence_event.starting_scene.resource_path
                    if sequence_event.starting_scene
                    else ""
                )
                var fallback_scene: String = Repositories.get_resource_path(
                    RepositoryTypes.SCENES, "portraited_scene"
                )
                SceneManager.swap_scenes(
                    self,
                    get_tree().current_scene,
                    scene_to_swap if not scene_to_swap.is_empty() else fallback_scene
                )
            GameEvent.SCENARIO_TYPES.Battle:
                pass

    if SceneManager.swapping:
        await SceneManager.load_complete
        var current_scene = get_tree().current_scene
        current_scene.process_mode = Node.PROCESS_MODE_DISABLED
        paused_scene = current_scene
    state_manager.restore_state(data.state, data.last_state)
    await get_tree().create_timer(0.1).timeout
    restored.emit()


## Sets [code]world_stage[/code] to [code]data.world[/code]; sets [code]seen_events[/code] to
## [code]data.seen_events[/code]; sets [code]GameManager.state[/code] to [code]data.state[/code]. It
## also sends [code]restored[/code] notifications. It pauses for
## [code]get_tree().create_timer(0.1).timeout[/code] before continuing.
func restore_from_checkpoint(data: Dictionary) -> void:
    CustomLogger.hint(
        self,
        self.full_load,
        "[color=#0F0]GameManager performing checkpoint load[/color]",
        CustomLogger.LEVEL.MILD
    )
    world_stage = data.world
    if data.has("seen_events") and seen_events != data.seen_events:
        seen_events = data.seen_events

    state_manager.restore_state(data.state, data.get("last_state", last_state))
    await get_tree().create_timer(0.1).timeout
    restored.emit()
#endregion
