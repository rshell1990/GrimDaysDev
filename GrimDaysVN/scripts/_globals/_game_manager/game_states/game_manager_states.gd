extends Node
## Selects the active game mode and remembers the preceding mode for restoration.
class_name GameManagerStates

## Shared fixed value for safe states.
const SAFE_STATES = [
    GameManagerStates.STATES.Navigation,
    GameManagerStates.STATES.Scenario,
    GameManagerStates.STATES.ScenarioSequence,
    GameManagerStates.STATES.ScenarioLewd,
    GameManagerStates.STATES.ScenarioSleep
]

## Named choices for states: [code]BeforeGame[/code], [code]Loading[/code], [code]Scenario[/code],
## [code]ScenarioSleep[/code], [code]ScenarioLewd[/code], [code]ScenarioSequence[/code],
## [code]ScenarioReplay[/code], [code]TransferDimension[/code], [code]TimeChanging[/code],
## [code]Navigation[/code], [code]Phone[/code], [code]Computer[/code], [code]Battle[/code],
## [code]Other[/code], [code]Paused[/code], [code]Input[/code], [code]Init[/code].
enum STATES {
    BeforeGame,  #0
    Loading,  # 1
    Scenario,  # 2
    ScenarioSleep,  #3
    ScenarioLewd,  #4
    ScenarioSequence,  #5
    ScenarioReplay,  #6
    TransferDimension,  #7
    TimeChanging,  #8
    Navigation,  #9
    Phone,  #10
    Computer,  #11
    Battle,  #12
    Other,  #13
    Paused,  #14
    Input,  #15
    Init = 16
}

## Lookup table for states; keys select the corresponding stored values.
var states: Dictionary
## Current game mode, used to decide which behavior and input are active.
var current_state: GameManagerState
## Previous game mode, used to decide which behavior and input are active.
var last_state: GameManagerState
## Published after the authoritative state pair is committed.
signal transitioned(state: STATES)

## Invalidates asynchronous work from an earlier visit, including to the same state.
var revision: int = 0
var _transitioning: bool = false
var _requests: Array[Dictionary] = []


## When the node is ready, this function sets [code]states[state.id][/code] to [code]state[/code];
## sets [code]current_state[/code] to [code]states[STATES.BeforeGame][/code].
func _ready() -> void:
    for state in get_children():
        if state is GameManagerState:
            states[state.id] = state

    if states.has(STATES.BeforeGame):
        current_state = states[STATES.BeforeGame]


## Serializes lifecycle and signal-triggered requests instead of recursively switching.
func change_state(new_state: STATES) -> void:
    _request({"state": new_state, "enter": true, "force": new_state == STATES.BeforeGame})


## Explicitly reruns current entry work (for rebuilding a loaded navigation scene).
func restart_current_state() -> void:
    if current_state:
        var previous: STATES = last_state.id if last_state else STATES.BeforeGame
        _request({"state": current_state.id, "previous": previous, "enter": true, "force": true})


## Restores saved state without replaying scene-entry actions.
func restore_state(new_state: STATES, previous: STATES) -> void:
    _request({"state": new_state, "previous": previous, "enter": false, "force": true})


## Resume the previous mode without replaying its scene-entry actions.
func restore_last_state_on_end() -> void:
    if last_state:
        _request({"state": last_state.id, "enter": false})


## Resume the previous mode and explicitly rerun its entry actions.
func restart_last_state_on_end() -> void:
    if last_state:
        _request({"state": last_state.id, "enter": true, "force": true})


## A completion belongs to one visit, not whichever state happens to be current.
func owns_state(expected: STATES, token: int) -> bool:
    return current_state != null and current_state.id == expected and revision == token


func complete_state(expected: STATES, token: int) -> void:
    if owns_state(expected, token) and last_state:
        _request({"state": last_state.id, "enter": false, "owner": expected, "token": token})


func _request(request: Dictionary) -> void:
    if not states.has(request.state) or not states.has(request.get("previous", request.state)):
        push_warning("Ignoring unknown game state: " + str(request))
        return
    _requests.append(request)
    if _transitioning:
        return
    _transitioning = true
    while not _requests.is_empty():
        var next: Dictionary = _requests.pop_front()
        if next.has("owner") and not owns_state(next.owner, next.token):
            continue
        if current_state and current_state.id == next.state and not next.get("force", false):
            continue
        var outgoing := current_state
        # Invalidate old callbacks before cleanup; keep the outgoing pair intact
        # until cleanup finishes. Nested requests wait for this commit.
        revision += 1
        if outgoing:
            outgoing.on_end()
        last_state = states[next.previous] if next.has("previous") else outgoing
        current_state = states[next.state]
        # Processing flags must also follow restoration (which skips on_start).
        for node: GameManagerState in states.values():
            node.process_mode = Node.PROCESS_MODE_INHERIT if node == current_state else Node.PROCESS_MODE_DISABLED
        transitioned.emit(current_state.id)
        if next.enter:
            current_state.on_start()
    _transitioning = false
