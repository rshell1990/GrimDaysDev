extends GameEvent
## Story event that enters a battle, waits for an accepted result and selects the victory or defeat
## follow-up event.
class_name GameEventBattle

## Encounter-owned opponents. Allies are resolved from the persistent runtime party.
@export var foes: Array[BattleUnitTemplate]
## The next event to run after victory. Kept as finished_event for authored compatibility.
@export var finished_event: GameEvent
## Defeat branch when require_victory is false.
@export var defeated_event: GameEvent
## Failed attempts must be retried; no defeat branch or finishing actions run.
@export var require_victory: bool = false
## A stable seed makes authored encounters and bug reports reproducible.
@export var battle_seed: int = 1
## Encounter rewards copied into the terminal result for downstream progression.
@export var rewards: Dictionary
## Optional stage background; unset preserves the battle scene's default texture.
@export var background_texture: Texture2D

## Accepted result from the most recently completed battle session.
var last_battle_result: BattleResult
## Story-to-battle session whose result this event is waiting for.
var _session: BattleStorySession
## Whether this event is waiting for its battle session to return a result.
var _awaiting_result: bool = false
## Whether this event has already finished or been cancelled, preventing repeated completion.
var _finished: bool = true
## Whether battle entry is waiting for the current dialogue timeline to finish.
var _waiting_for_timeline: bool = false
## Counter used to invalidate scheduled battle starts after cancellation or a newer request.
var _start_generation: int = 0


## Marks this event as a battle event when it is created.
func _init() -> void:
    scenario_type = SCENARIO_TYPES.Battle


## Checks required follow-up events, then waits for dialogue to end before scheduling battle entry.
## Ignores repeated requests while already waiting or running.
func start() -> void:
    if _awaiting_result or _waiting_for_timeline or is_instance_valid(_session):
        return
    if finished_event == null or (not require_victory and defeated_event == null):
        CustomLogger.warn(
            self,
            start,
            "Battle %s requires a victory event and, unless victory is required, a defeat event." % id,
            CustomLogger.LEVEL.IMPORTANT
        )
        return
    _start_generation += 1
    VNSignalBus.reset_sub_systems.connect(_cancel_pending_start, CONNECT_ONE_SHOT)
    # An explicit trigger can occur on the last Dialogic event or in its ending
    # callback. Do not free its scene or pause Dialogic before timeline_ended.
    if Dialogic.current_timeline:
        _waiting_for_timeline = true
        Dialogic.timeline_ended.connect(_on_timeline_ended, CONNECT_ONE_SHOT)
        return
    _waiting_for_timeline = true
    _on_timeline_ended.call_deferred()


## Invalidates a scheduled battle start and disconnects the timeline and reset listeners.
func _cancel_pending_start() -> void:
    _start_generation += 1
    _waiting_for_timeline = false
    if Dialogic.timeline_ended.is_connected(_on_timeline_ended):
        Dialogic.timeline_ended.disconnect(_on_timeline_ended)
    if VNSignalBus.reset_sub_systems.is_connected(_cancel_pending_start):
        VNSignalBus.reset_sub_systems.disconnect(_cancel_pending_start)


## Schedules the waiting battle start with the current request number, so a cancelled request can be
## rejected later.
func _on_timeline_ended() -> void:
    if not _waiting_for_timeline:
        return
    _begin_battle.call_deferred(_start_generation)


## Starts the production battle scene with the existing party and configured opponents. Rejects
## outdated requests and logs startup failures without advancing the story.
func _begin_battle(generation: int) -> void:
    if generation != _start_generation or _awaiting_result or is_instance_valid(_session):
        return
    _waiting_for_timeline = false
    if VNSignalBus.reset_sub_systems.is_connected(_cancel_pending_start):
        VNSignalBus.reset_sub_systems.disconnect(_cancel_pending_start)
    var scene: PackedScene = load(Repositories.get_resource_path(RepositoryTypes.SCENES, "battle")) # lint:ignore load-in-var,line-length -- Runtime repository-selected scene.
    _session = BattleStorySession.new()
    SceneManager.add_child(_session)
    _session.completed.connect(_on_battle_finished.bind(_session.get_instance_id()))
    _session.cancelled.connect(_on_cancelled.bind(_session.get_instance_id()))
    # The party still lives under the legacy autoload, but no debug battle
    # controller orchestration, selectors or headless runner are used here.
    if not _session.begin(
        BattleController.party_manager,
        foes,
        id,
        battle_seed,
        rewards,
        SceneManager.get_tree().current_scene,
        scene,
        require_victory,
        background_texture
    ):
        CustomLogger.error(
            self, start, "Battle event %s could not start: %s" % [id, _session.last_error], CustomLogger.LEVEL.IMPORTANT
        )
        _session.queue_free()
        _session = null
        return
    last_battle_result = null
    _awaiting_result = true
    _finished = false
    if GameManager.state != GameManagerStates.STATES.Battle:
        GameManager.change_state(GameManagerStates.STATES.Battle)
    UIDirector.reveal_screen()
    UIDirector.fade_flag_hide()


## Accepts a result only from the current battle session, stores it, and runs this event's finishing
## behavior.
func _on_battle_finished(result: BattleResult, session_id: int = 0) -> void:
    if not _awaiting_result or not is_instance_valid(_session) or _session.get_instance_id() != session_id:
        return
    _awaiting_result = false
    _session = null
    last_battle_result = result
    finish()


## Stops waiting for the matching battle session without running a follow-up story branch.
func _on_cancelled(session_id: int) -> void:
    if not is_instance_valid(_session) or _session.get_instance_id() != session_id:
        return
    _awaiting_result = false
    _finished = true
    _session = null


## Runs finishing actions and the appropriate story branch for an accepted result. Error, draw,
## cancellation and required-victory defeat do not advance the story.
func finish() -> void:
    if _finished or _awaiting_result or last_battle_result == null:
        return
    _finished = true
    if GameManager.state == GameManagerStates.STATES.Other:
        return
    if last_battle_result.outcome == BattleResult.OUTCOME.ERROR:
        CustomLogger.error(self, finish, last_battle_result.error, CustomLogger.LEVEL.IMPORTANT)
        return
    if not last_battle_result.is_victory() and (require_victory or not last_battle_result.is_defeat()):
        return
    if GameManager.state == GameManagerStates.STATES.Battle:
        GameManager.change_state(GameManagerStates.STATES.Scenario)
    super()
    var next_event: GameEvent = (
        defeated_event if last_battle_result and last_battle_result.is_defeat() else finished_event
    )
    if next_event == null:
        return
    VNSignalBus.event_found.emit(next_event)
