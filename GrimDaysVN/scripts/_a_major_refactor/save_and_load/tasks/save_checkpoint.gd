extends Task
## Queued rollback-save operation that checks battle restrictions before collecting or writing
## state.
class_name TaskSaveCheckpoint

## Name identifying the save slot this operation uses.
var slot_name: String
## Additional values stored with the save slot, separate from the scene’s saved state.
var extra_info: Dictionary


## During creation, this function sets [code]extra_info["lines_read"][/code] to
## [code]Dialogic.VAR.lines_read[/code].
func _init(task_name: StringName) -> void:
    super(task_name)
    SystemHelpers.set_prefix_if_empty()
    extra_info["lines_read"] = Dialogic.VAR.lines_read
    var slot_name_to_format = "{prefix}___rollback-save___{number}"
    slot_name = slot_name_to_format.format(
        {"prefix": Dialogic.VAR.prefix, "number": Dialogic.VAR.lines_read % SystemLimits.CHECKPOINTS}
    )


## Checks battle save restrictions before marking the checkpoint task ready.
func _prepare() -> void:
    if _battle_blocks_save():
        return
    goto_ready()


## Collects current state and writes the rollback slot and rollback data. Rechecks battle save
## restrictions after waiting for data, before changing any slot files.
func _complete() -> void:
    if _battle_blocks_save():
        return
    var current_data = await SaveAndLoadSystemManager.get_persistent_data()
    if _battle_blocks_save():
        return
    if Dialogic.Save.has_slot(slot_name):
        Dialogic.Save.delete_slot(slot_name)
    Dialogic.Save.add_empty_slot(slot_name)
    Dialogic.Save.save(slot_name, false, Dialogic.Save.ThumbnailMode.NONE, extra_info)
    SystemAdministrators.set_current_rollback_data(current_data)
    #CustomLogger.confirm(self, _complete, str(current_data), 5)
    Dialogic.Save.save_file(slot_name, "game_info", current_data)
    Dialogic.Save.save_file(slot_name, "all_rollback", SystemAdministrators.get_current_rollback_data())
    goto_completed()


## Returns false if saving is allowed. Otherwise reports the rejection, marks this task as failed,
## and returns true before any save write is attempted.
func _battle_blocks_save() -> bool:
    var reason := SaveAndLoadSystemManager.get_save_block_reason()
    if reason.is_empty():
        return false
    SaveAndLoadSystemManager.report_save_rejected(reason)
    goto_failed()
    return true
