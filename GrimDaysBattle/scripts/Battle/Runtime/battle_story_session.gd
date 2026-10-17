extends Node
## Replaces the story scene with the battle scene. The battle scene handles retries,
## and GameEventBattle chooses which story event follows the final result.
class_name BattleStorySession

## Notification for completed. Supplies [code]result[/code] to connected functions.
signal completed(result: BattleResult)
## Notification for cancelled.
signal cancelled

## Shared fixed value for group.
const GROUP := &"battle_story_sessions"
## Named choices for state: [code]IDLE[/code], [code]ACTIVE[/code], [code]RETURNING[/code],
## [code]CLOSED[/code].
enum STATE { IDLE, ACTIVE, RETURNING, CLOSED }

## Current step in switching from the story to battle and passing the result back to the story.
var state: STATE = STATE.IDLE
## Battle scene created for this session. Kept after completion until the next scene replaces it.
var encounter: BattleEncounterScene
## Most recent story-session startup rejection or encounter startup error.
var last_error: String = ""
## Records whether cleanup has already happened, so it is not repeated.
var _closed: bool = false


## Checks that battle can start, starts it, then replaces the current story scene and schedules that
## old scene for deletion.
func begin(
    party: BattlePartyManager,
    foes: Array[BattleUnitTemplate],
    encounter_id: StringName,
    seed_value: int,
    rewards: Dictionary,
    caller: Node,
    scene: PackedScene,
    require_victory: bool = false,
    background_texture: Texture2D = null,
) -> bool:
    if state != STATE.IDLE or not is_inside_tree():
        return _reject("A story session must be live and unused.")
    if not get_tree().get_nodes_in_group(GROUP).is_empty() or SceneManager.swapping:
        return _reject("Another battle or scene transition is already active.")
    if not is_instance_valid(caller) or caller != get_tree().current_scene or caller.is_queued_for_deletion():
        return _reject("A live current story scene is required.")
    if not scene or not is_instance_valid(party) or caller == party or caller.is_ancestor_of(party):
        return _reject("The encounter requires a scene and a persistent party outside the caller.")
    var instance := scene.instantiate()
    if not instance is BattleEncounterScene:
        instance.free()
        return _reject("The battle route must be a production encounter scene.")
    encounter = instance
    state = STATE.ACTIVE
    add_to_group(GROUP)
    get_tree().root.add_child(encounter)
    encounter.stage.set_background_texture(background_texture)
    encounter.encounter_completed.connect(_on_result)
    encounter.tree_exiting.connect(_on_encounter_exiting)
    VNSignalBus.reset_sub_systems.connect(cancel)
    if not encounter.begin_session(
        party, foes, encounter_id, seed_value, {"event_id": encounter_id}, rewards, require_victory
    ):
        last_error = encounter.last_error
        state = STATE.RETURNING
        _close()
        encounter.queue_free()
        return false
    # The timeline has ended before this call. Its scene is replaced, not paused
    # for return; the selected follow-up event owns the next story scene.
    get_tree().current_scene = encounter
    SceneManager.active_node = encounter
    SceneManager.last_swapped_scene = caller.scene_file_path
    caller.process_mode = Node.PROCESS_MODE_DISABLED
    caller.queue_free()
    return true


## Returns the reason saving is blocked while this story-to-battle session is open, or an empty
## string otherwise.
func get_save_block_reason() -> String:
    return "Saving is unavailable during a battle scene handoff." if state != STATE.IDLE and not _closed else ""


## Accepts the completed battle result once, then schedules story completion after battle
## notifications finish.
func _on_result(result: BattleResult) -> void:
    if state != STATE.ACTIVE or not result or not result.finalized:
        return
    state = STATE.RETURNING
    # Never free the encounter while its resolver emits a terminal signal.
    _complete.call_deferred(result)


## Cleans up the session, announces its accepted result, and schedules this session node for
## deletion.
func _complete(result: BattleResult) -> void:
    if state != STATE.RETURNING:
        return
    _close()
    completed.emit(result)
    queue_free()


## Prevents a waiting result from continuing the story, stops the battle, and schedules
## cancellation.
func cancel() -> void:
    if state not in [STATE.ACTIVE, STATE.RETURNING]:
        return
    # Invalidate queued result callbacks immediately; cancellation never branches.
    state = STATE.CLOSED
    if is_instance_valid(encounter):
        encounter.cancel_session()
    _cancel.call_deferred()


## Cleans up the session, announces cancellation, and schedules this session node for deletion.
func _cancel() -> void:
    _close()
    cancelled.emit()
    queue_free()


## Cancels the story session if its battle scene exits unexpectedly.
func _on_encounter_exiting() -> void:
    cancel()


## Stops listening for battle notifications and cancels combat once. Keeps the finished battle scene
## until the next scene replaces it.
func _close() -> void:
    if _closed or state == STATE.IDLE:
        return
    _closed = true
    if VNSignalBus.reset_sub_systems.is_connected(cancel):
        VNSignalBus.reset_sub_systems.disconnect(cancel)
    if is_instance_valid(encounter):
        encounter.tree_exiting.disconnect(_on_encounter_exiting)
        encounter.encounter_completed.disconnect(_on_result)
        encounter.cancel_session()
    # Keep the finished scene as the outgoing scene for the next event/load.
    # Do not resurrect the already-ended VN scene or resume its timeline.
    state = STATE.CLOSED
    remove_from_group(GROUP)


## Records a startup rejection reason and returns false.
func _reject(message: String) -> bool:
    last_error = message
    return false


## Cleans up notification connections and announces cancellation if this node was removed before the
## session closed.
func _exit_tree() -> void:
    var interrupted := not _closed and state != STATE.IDLE
    _close()
    if interrupted:
        cancelled.emit()
