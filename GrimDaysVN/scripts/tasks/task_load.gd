#region TASK LOAD CHECKPOINT
##
##
##
class_name TaskLoadCheckpointOld
extends Task
#endregion

#region VARS
## Pattern used to build a rollback save-slot name from its prefix and number.
var slot_name_to_format: String = "{prefix}___rollback-save___{number}"
## Name identifying the save slot this operation uses.
var slot_name: String
## Number identifying the rollback checkpoint to restore.
var to_load: int
## Lookup table for loaded state; keys select the corresponding stored values.
var loaded_state: Dictionary = {}
#endregion


## Check if a rollback is possible, if not cancel. Otherwise will
func _prepare() -> void:
    CustomLogger.warn(self, self._prepare, " will pause Dialogic.", CustomLogger.LEVEL.VERBOSE)
    Dialogic.paused = true
    Dialogic.Inputs.auto_skip.enabled = false

    var info: Dictionary = Dialogic.Save.load_file(slot_name, "game_info", {})
    loaded_state["type"] = RollbackCommands.LOADED
    loaded_state["info"] = info
    assert(loaded_state.info.has("game_manager"))
    var saved_event = loaded_state.info.game_manager.current_event
    if saved_event:
        var saved_timeline = (
            Repositories.get_info(RepositoryTypes.EVENTS, loaded_state.info.game_manager.current_event).timeline
        )
        if Dialogic.current_timeline != saved_timeline:
            Dialogic.end_timeline()
            var super_signal = SuperSignal.new()
            SystemHelpers.add_child(super_signal)
            super_signal.start_tracking_time_or_signal(Dialogic.timeline_ended, VNAnimationTimes.FAST)
            await super_signal.tracking_finished
            super_signal.queue_free()

    goto_ready()


## Clears [code]Dialogic[/code]; sets [code]Dialogic.VAR.lines_read[/code] to [code]to_load[/code].
## It pauses for [code]SaveAndLoadSystemManager.restore_data(loaded_state.info)[/code] before
## continuing.
func _complete() -> void:
    await SaveAndLoadSystemManager.restore_data(loaded_state.info)
    Dialogic.clear()
    Dialogic.Save.load(slot_name)
    Dialogic.VAR.lines_read = to_load
    goto_completed()


## Marks this task as completed when this task step is called.
func _cancel() -> void:
    # In case you need to clean something up when a task has failed.
    goto_completed()
