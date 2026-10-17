#region TASK LOAD CHECKPOINT
##
##
##
class_name TaskLoadCheckpoint
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


#region PREPARE
## Check if a rollback is possible, if not cancel. Otherwise will cancel the task.
func _prepare() -> void:
    to_load = Dialogic.VAR.lines_read - 1
    slot_name = slot_name_to_format.format(
        {"prefix": Dialogic.VAR.prefix, "number": to_load % SystemLimits.CHECKPOINTS}
    )
    CustomLogger.warn(self, self._prepare, " is pausing Dialogic.", CustomLogger.LEVEL.VERBOSE)
    Dialogic.paused = true
    Dialogic.Inputs.auto_skip.enabled = false

    var info: Dictionary = Dialogic.Save.load_file(slot_name, "game_info", {})
    loaded_state["type"] = RollbackCommands.LOADED
    loaded_state["info"] = info

    assert(loaded_state.info.has("game_manager"))

    var saved_event = loaded_state.info.game_manager.current_event

    if not saved_event:
        goto_ready()
        return

    goto_ready()


#endregion


#region COMPLETE
## Clears [code]Dialogic[/code]; sets [code]Dialogic.VAR.lines_read[/code] to [code]to_load[/code].
## It pauses for [code]SaveAndLoadSystemManager.data_restored[/code] before continuing.
func _complete() -> void:
    SaveAndLoadSystemManager.restore_data(loaded_state)
    await SaveAndLoadSystemManager.data_restored
    Dialogic.clear()
    Dialogic.Save.load(slot_name)
    Dialogic.VAR.lines_read = to_load
    goto_completed()


#endregion


#region CANCEL
## Marks this task as completed when this task step is called.
func _cancel() -> void:
    goto_completed()
#endregion
