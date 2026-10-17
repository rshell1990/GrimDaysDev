extends CanvasLayer
## Owns a modal preparation visit, not character data. Navigation can request it
## directly; story access must be an explicit call from a running timeline.
## Pausing the tree preserves Navigation without re-running its scene-entry code.
class_name BattlePreparationSession

## Emitted after the panel is dismissed and the preparation lease released.
signal closed

## Production party-preparation panel instantiated for a session.
const PANEL_SCENE := preload("res://GrimDaysBattle/scenes/ui/party_management.tscn")

## Story states in which opening preparation is permitted.
const STORY_STATES := [
    GameManagerStates.STATES.Scenario,
    GameManagerStates.STATES.ScenarioSequence,
    GameManagerStates.STATES.ScenarioLewd,
    GameManagerStates.STATES.ScenarioSleep
]

## Current panel instance, freed when the session finishes.
var panel: BattlePreparationPanel
## Whether this session currently owns an open preparation overlay.
var active: bool = false
## Party manager whose preparation lease this session holds.
var _party: BattlePartyManager
## Story node that opened preparation; used to reject stale continuation.
var _caller: Node
## Story state captured when preparation opened.
var _state: int
## Timeline associated with the opening Call, if any.
var _timeline: DialogicTimeline
## Previous Dialogic pause value restored when the session finishes.
var _was_dialogic_paused: bool
## Opening Dialogic Call whose continuation may be resumed exactly once.
var _call_event: DialogicCallEvent
## Captured Call index checked before resuming the timeline.
var _event_index: int = -1
## Invalidates deferred continuation from an earlier session.
var _generation: int = 0


## Sets up input that works while the game is paused and connects reset and timeline-change
## cancellation. Starts hidden.
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 100
    add_to_group(&"party_preparation_sessions")
    VNSignalBus.reset_sub_systems.connect(cancel)
    Dialogic.timeline_ending.connect(_on_timeline_ending)
    Dialogic.timeline_started.connect(_on_timeline_started)
    hide()


## No global hotkey: the two explicit UIDirector entry points choose the policy.
func open(party: BattlePartyManager, explicit_story: bool = false) -> bool:
    if active or not is_instance_valid(party) or get_tree().paused or SceneManager.swapping:
        return false
    if SaveAndLoadSystemManager.restoring_data or SaveAndLoadSystemManager._operation_in_progress:
        return false
    if not SaveAndLoadSystemManager.get_save_block_reason().is_empty():
        return false
    var state: int = GameManager.state
    if explicit_story:
        if state not in STORY_STATES or not Dialogic.current_timeline or Dialogic.paused:
            return false
        # Own this exact Call event. Otherwise handle_event() leaves a coroutine
        # awaiting dialogic_resumed even after a load/replacement timeline.
        var event = Dialogic.get_meta(&"previous_event", null)
        if (
            event is not DialogicCallEvent
            or event.autoload_name != "UIDirector"
            or event.method != "show_story_party_preparation"
            or not event.event_finished.is_connected(Dialogic.handle_next_event)
        ):
            return false
    elif state != GameManagerStates.STATES.Navigation or Dialogic.current_timeline:
        return false
    if not party.acquire_preparation(self):
        return false
    _party = party
    _caller = get_tree().current_scene
    _state = state
    _timeline = Dialogic.current_timeline
    _was_dialogic_paused = Dialogic.paused
    _generation += 1
    active = true
    if _timeline:
        _call_event = Dialogic.get_meta(&"previous_event")
        _event_index = Dialogic.current_event_idx
        _call_event.event_finished.disconnect(Dialogic.handle_next_event)
        Dialogic.paused = true
    get_tree().paused = true
    panel = PANEL_SCENE.instantiate() as BattlePreparationPanel
    add_child(panel)
    panel.close_requested.connect(close)
    panel.present(party, self)
    show()
    return true


## Changes commit through party APIs immediately. Close only releases UI/pause
## ownership; it neither reloads Navigation nor rewinds skill investments.
func close() -> void:
    _finish(true)


## Cancellation releases ownership without continuing an interrupted Call event.
func cancel() -> void:
    _generation += 1
    _finish(false)


## Closes the panel, releases the party reservation and pause, and optionally schedules
## continuation of the same story call.
func _finish(resume_story: bool) -> void:
    if not active:
        return
    active = false
    hide()
    if is_instance_valid(panel):
        panel.dismiss()
        panel.queue_free()
    panel = null
    if is_instance_valid(_party):
        _party.release_preparation(self)
    _party = null
    get_tree().paused = false
    if _timeline and (Dialogic.current_timeline == _timeline or not Dialogic.current_timeline):
        Dialogic.paused = _was_dialogic_paused
    if resume_story and _call_event:
        var caller_id: int = _caller.get_instance_id() if is_instance_valid(_caller) else 0
        _resume_call.call_deferred(_generation, _timeline, _call_event, _event_index, _state, caller_id)
    _timeline = null
    _call_event = null
    _caller = null
    closed.emit()


## Check again after the input frame; a late Done cannot advance another timeline.
func _resume_call(
    generation: int, timeline: DialogicTimeline, event: DialogicCallEvent, index: int, state: int, caller_id: int
) -> void:
    var scene := get_tree().current_scene
    var scene_id: int = scene.get_instance_id() if is_instance_valid(scene) else 0
    if (
        generation == _generation
        and not active
        and Dialogic.current_timeline == timeline
        and Dialogic.current_event_idx == index
        and Dialogic.get_meta(&"previous_event", null) == event
        and GameManager.state == state
        and scene_id == caller_id
    ):
        Dialogic.handle_next_event()


## External state/scene changes cancel the visit rather than retaining stale units.
func _process(_delta: float) -> void:
    if (
        active
        and (
            GameManager.state != _state
            or get_tree().current_scene != _caller
            or Dialogic.current_timeline != _timeline
            or not is_instance_valid(_party)
        )
    ):
        cancel()


## Handles preparation input while open. Cancel closes the panel; input is consumed so it does not
## reach the scene underneath.
func _unhandled_input(event: InputEvent) -> void:
    if active:
        if event.is_action_pressed(&"ui_cancel"):
            close()
        get_viewport().set_input_as_handled()


## Cancels preparation when the timeline that opened it ends.
func _on_timeline_ending(timeline: DialogicTimeline) -> void:
    if active and timeline == _timeline:
        cancel()


## start_timeline emits before executing the replacement's first event. Release
## our inherited pause now, so the replacement cannot enter a paused coroutine.
func _on_timeline_started() -> void:
    if active and Dialogic.current_timeline != _timeline:
        Dialogic.paused = _was_dialogic_paused
        cancel()


## Returns a message asking the player to close preparation while it is open, or an empty string
## otherwise.
func get_save_block_reason() -> String:
    return "Close party preparation before saving." if active else ""


## Cancels preparation and releases its pause and party reservation.
func _exit_tree() -> void:
    cancel()
