#region SAVE AND LOAD MANAGER
#class_name SaveAndLoadSystemManager
## Coordinates registered save data, queued save/load work and restoration order. Active battles can
## block save requests.
extends BaseSystemManager
#endregion

#region SIGNAL
## Notification for checkpoint saved.
signal checkpoint_saved
## Notification for data restored.
signal data_restored
## Emitted when a save request is rejected before it reaches the task queue.
signal save_rejected(reason: String)
## Emitted after a requested slot is fully restored.
signal load_succeeded(slot_name: String)
## Emitted when preflight rejects a load without clearing the running game.
signal load_failed(slot_name: String, report: String)
## Save schema, manifest and integrity-validation helper.
const INTEGRITY = preload("res://GrimDaysVN/scripts/_a_major_refactor/save_and_load/save_integrity.gd")
## Dialog script used to present local save/load failure reports.
const FAILURE_DIALOG = preload("res://GrimDaysVN/scripts/ui/save_failure_dialog.gd")
## Serializes normal save/load requests and blocks rollback during these operations.
var _operation_in_progress: bool = false
## Current error-report modal, or null.
var failure_dialog: CanvasLayer
#endregion

#region VARIABLES
## Nodes registered for saving, looked up by each node’s save name.
var nodes_with_data: Dictionary
## Save names of nodes registered during restoration, so their saved data can also be applied.
var node_keys_added_while_loading: PackedStringArray = PackedStringArray()
## Whether saved state is currently being applied to the running game.
var restoring_data: bool
#endregion


#region SAVE
## Get nodes with information that should be 'saved' thus making the nodes persistent.
func get_persistent_data() -> Dictionary:
    var dictionary = {}
    for node in nodes_with_data:
        dictionary[node] = await nodes_with_data[node]._get_state()

    return dictionary


## Awaits this save task and returns true only after verified commit; retains battle save guards.
func save_game(slot_name: String, save_name: String) -> bool:
    var block_reason := get_save_block_reason()
    if not block_reason.is_empty():
        report_save_rejected(block_reason)
        return false
    if _operation_in_progress or task_queue.busy:
        return false
    _operation_in_progress = true
    var task := TaskSaveGame.new(&"Save Game", slot_name, save_name)
    task_queue.put_task(task)
    var success: bool = await task.settled
    if not task.failure.is_empty():
        await show_save_failure(task.failure, "metadata" if success else "saving")
    _operation_in_progress = false
    return success


## Queues a rollback checkpoint when allowed and listens for its completion. Returns false if
## blocked or already listening for the same checkpoint task.
func save_checkpoint() -> bool:
    if _operation_in_progress:
        return false
    var block_reason := get_save_block_reason()
    if not block_reason.is_empty():
        report_save_rejected(block_reason)
        return false
    var task = TaskSaveCheckpoint.new(&"Save Checkpoint")
    if task_queue.task_completed.is_connected(on_checkpoint_saved.bind(task.slot_name)):
        return false
    task_queue.put_task(task)
    task_queue.task_completed.connect(on_checkpoint_saved.bind(task.slot_name))
    return true


## Returns whether persistent state is currently stable enough to serialize.
func can_save_game() -> bool:
    return get_save_block_reason().is_empty()


## Transient battle/preparation sessions prohibit serializing paused modal state.
func get_save_block_reason() -> String:
    for group in [&"battle_story_sessions", &"battle_save_guards", &"party_preparation_sessions"]:
        for guard in get_tree().get_nodes_in_group(group):
            var reason: String = guard.get_save_block_reason()
            if not reason.is_empty():
                return reason
    return BattleController.get_save_block_reason()


## Publishes a rejected save request without enqueueing any persistence task.
func report_save_rejected(reason: String) -> void:
    CustomLogger.warn(self, report_save_rejected, reason, CustomLogger.LEVEL.IMPORTANT)
    save_rejected.emit(reason)


## Announces completion only for the matching checkpoint slot, disconnects its listener, and
## increments the recorded dialogue-line count.
func on_checkpoint_saved(finished_task, waiting_task) -> void:
    if finished_task.slot_name != waiting_task:
        return
    checkpoint_saved.emit()
    task_queue.task_completed.disconnect(on_checkpoint_saved.bind(waiting_task))

    SystemHelpers.increment_lines_read()


#endregion


#region LOAD
## Validates the slot before cancelling battles, hiding menus or resetting persistent systems.
## Applies only the payloads read by preflight and awaits this particular load task.
func load_game(slot_name: String) -> bool:
    if _operation_in_progress or task_queue.busy:
        return false
    _operation_in_progress = true
    var checked := INTEGRITY.inspect_slot(Dialogic.Save, slot_name)
    if checked.error != OK:
        load_failed.emit(slot_name, INTEGRITY.report(checked, "loading"))
        await show_save_failure(checked, "loading")
        _operation_in_progress = false
        return false
    await cancel_story_battles()
    if is_instance_valid(UIDirector.menu_operator.active_menu):
        await UIDirector.menu_operator.fade_out()
    await UIDirector.cover_screen()
    GameManager.change_state(GameManagerStates.STATES.Loading)
    Dialogic.paused = true
    restoring_data = true
    for node in nodes_with_data.values():
        if node.has_method("reset"):
            node.reset()
    var task := TaskLoadGame.new(&"Load Game", slot_name, checked)
    task_queue.put_task(task)
    var success: bool = await task.settled
    await on_load_finished()
    if success:
        load_succeeded.emit(slot_name)
    _operation_in_progress = false
    return success


## Stores a minimal local report and waits for the player's acknowledgement.
func show_save_failure(failure: Dictionary, operation: String) -> void:
    var report := INTEGRITY.report(failure, operation)
    var report_path := ""
    if DirAccess.make_dir_recursive_absolute("user://bug_reports") == OK:
        var path := "user://bug_reports/save-%s-%s.txt" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]
        var file := FileAccess.open(path, FileAccess.WRITE)
        if file:
            file.store_string(report)
            file.flush()
            if file.get_error() == OK:
                report_path = path
    failure_dialog = FAILURE_DIALOG.new()
    failure_dialog.report_text = report
    failure_dialog.report_path = report_path
    failure_dialog.operation = operation
    add_child(failure_dialog)
    await failure_dialog.acknowledged
    failure_dialog = null


## Clears old rollback saves, reconnects dialogue completion when appropriate, resumes the paused
## scene and reveals the screen.
func on_load_finished() -> void:
    clear_rollback()
    if Dialogic.current_timeline and GameManager.state in GameManagerStates.SAFE_STATES:
        GameManager.reconnect_to_timeline_end()

    if GameManager.paused_scene:
        GameManager.paused_scene.process_mode = Node.PROCESS_MODE_INHERIT
        GameManager.paused_scene = null
    await UIDirector.reveal_screen()
    Dialogic.paused = false
    restoring_data = false


## Cancels story battles, shows the rollback indicator and queues restoration of the previous
## checkpoint.
func load_checkpoint() -> void:
    if _operation_in_progress or task_queue.busy:
        return
    await cancel_story_battles()
    restoring_data = true
    UIDirector.toggle_rollback_indicator()
    task_queue.put_task(TaskLoadCheckpoint.new(&"Load Checkpoint"))
    task_queue.queue_finished.connect(on_checkpoint_loaded)


## Release borrowed allies and cancel continuation before restore/reset can
## replace permanent runtime units. Never let a late result resume old story.
func cancel_story_battles() -> void:
    for preparation in get_tree().get_nodes_in_group(&"party_preparation_sessions"):
        preparation.cancel()
    for session in get_tree().get_nodes_in_group(&"battle_story_sessions"):
        if not is_instance_valid(session):
            continue
        session.cancel()
        await session.tree_exited


## Disconnects the checkpoint listener, resumes dialogue and the paused scene, and clears the
## loading indicator/state.
func on_checkpoint_loaded() -> void:
    task_queue.queue_finished.disconnect(on_checkpoint_loaded)
    restoring_data = false
    if Dialogic.paused:
        Dialogic.paused = false
    UIDirector.toggle_rollback_indicator()
    CustomLogger.confirm(self, self.on_checkpoint_loaded, "Checkpoint loaded.", CustomLogger.LEVEL.VERY_VERBOSE)
    if GameManager.paused_scene:
        GameManager.paused_scene.process_mode = Node.PROCESS_MODE_INHERIT
        GameManager.paused_scene = null
    restoring_data = false


## Restores the game manager, then the clock, then other registered systems and newly added nodes.
## Completion listeners are armed before each restore, supporting synchronous and asynchronous nodes.
func restore_data(data: Dictionary) -> void:
    restoring_data = true

    var node_keys = nodes_with_data.keys()
    node_keys.remove_at(node_keys.find("game_manager"))

    await _restore_node(nodes_with_data["game_manager"], data.info["game_manager"])
    if nodes_with_data.has("in_game_time") and data.info.has("in_game_time"):
        node_keys.erase("in_game_time")
        await _restore_node(nodes_with_data["in_game_time"], data.info["in_game_time"])

    for node_save_name in node_keys:
        if data.info.has(node_save_name) and nodes_with_data.has(node_save_name):
            CustomLogger.confirm(self, self.restore_data, str(data.info[node_save_name]), CustomLogger.LEVEL.MILD)
            await _restore_node(nodes_with_data[node_save_name], data.info[node_save_name])
        else:
            CustomLogger.warn(
                self, self.restore_data, node_save_name + " does not exist in the saved data.", CustomLogger.LEVEL.MILD
            )

    while not node_keys_added_while_loading.is_empty():
        CustomLogger.hint(
            self,
            self.restore_data,
            "Persistent nodes added by other nodes detected, now restoring..." + node_keys_added_while_loading.get(0),
            CustomLogger.LEVEL.VERY_VERBOSE
        )
        if (
            not data.info.has(node_keys_added_while_loading.get(0))
            or not nodes_with_data.has(node_keys_added_while_loading.get(0))
        ):
            node_keys_added_while_loading.remove_at(0)
            continue
        await _restore_node(
            nodes_with_data[node_keys_added_while_loading.get(0)],
            data.info[node_keys_added_while_loading.get(0)],
        )
        node_keys_added_while_loading.remove_at(0)

    data_restored.emit()


## Arms the completion listener before restore() is invoked. Persistent nodes
## are allowed to complete synchronously or asynchronously.
func _restore_node(node: Node, saved_data: Dictionary) -> void:
    # A reference container lets the callback update state visible here; scalar
    # lambda captures are values in GDScript.
    var state := {"completed": false}
    var mark_completed := func() -> void: state.completed = true
    node.restored.connect(mark_completed, CONNECT_ONE_SHOT)
    node.restore(saved_data)
    if not state.completed:
        await node.restored


#endregion


#region OTHER
## Registers a node under its save_name and arranges its removal when it leaves the scene. Nodes
## added during loading are also queued for restoration.
func add_node(node) -> void:
    CustomLogger.confirm(
        self,
        self.add_node,
        "Adding: " + str(node) + " to nodes with data, with the key: " + str(node.save_name),
        CustomLogger.LEVEL.VERY_VERBOSE
    )
    if restoring_data:
        node_keys_added_while_loading.append(node.save_name)
    nodes_with_data.set(node.save_name, node)
    node.tree_exiting.connect(remove_node.bind(node))


## Disconnects the node's exit listener and removes its save entry.
func remove_node(node) -> void:
    CustomLogger.confirm(
        self,
        self.remove_node,
        "Removing: " + str(node) + " to nodes with data, with the key: " + str(node.save_name),
        CustomLogger.LEVEL.VERY_VERBOSE
    )
    node.tree_exiting.disconnect(remove_node.bind(node))
    nodes_with_data.erase(node.save_name)


## Resets the recorded dialogue-line count and deletes save slots whose names identify them as
## rollback checkpoints.
func clear_rollback() -> void:
    CustomLogger.confirm(
        self, self.clear_rollback, "[u] ALL OLD ROLLBACK DELETED [/u]", CustomLogger.LEVEL.VERY_VERBOSE
    )
    Dialogic.VAR.set_variable("lines_read", 0)
    for slot_name in Dialogic.Save.get_slot_names():
        var split_name = slot_name.split("___")
        if "rollback-save" in split_name:
            Dialogic.Save.delete_slot(slot_name)
#endregion
