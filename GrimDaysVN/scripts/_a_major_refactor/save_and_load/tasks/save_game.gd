extends Task
## Queued normal-save operation. Collects game state and writes a slot only while saving is allowed.
class_name TaskSaveGame
## Emitted after this task succeeds or fails, independent of unrelated queued work.
signal settled(success: bool)
## Helper validating and writing the staged save's integrity manifest.
const INTEGRITY = preload("res://GrimDaysVN/scripts/_a_major_refactor/save_and_load/save_integrity.gd")
## Structured failure or metadata warning, shown by the save manager.
var failure: Dictionary
## Name identifying the save slot this operation uses.
var slot_name: String
## Save-slot summary containing the date, player-supplied label and readable play-progress
## information.
var info: Dictionary
## Additional values stored with the save slot, separate from the scene’s saved state.
var extra_info: Dictionary
## Player-supplied label stored in this save slot’s display information.
var save_name: String


## During creation, this function sets [code]slot_name[/code] to [code]sent_slot_name[/code]; sets
## [code]save_name[/code] to [code]input_name[/code].
func _init(task_name: StringName, sent_slot_name: String, input_name: String) -> void:
    super(task_name)
    slot_name = sent_slot_name
    save_name = input_name


## Checks that saving is allowed, builds the slot's date/name/play-summary information, and marks
## the task ready.
func _prepare() -> void:
    if _battle_blocks_save():
        return
    info["date"] = Time.get_datetime_dict_from_system()
    info["save_name"] = save_name
    var player_money = ""
    var stats_text = "| Playtime: "
    stats_text += GameManager.get_time_played()
    stats_text += " | "
    stats_text += SystemAdministrators.get_location_as_string(SystemAdministrators.current_location())
    stats_text += " | Money: $"
    stats_text += player_money
    stats_text += " | Day: "
    stats_text += SystemAdministrators.get_day_name(SystemAdministrators.current_day())
    stats_text += " | Week: "
    stats_text += str(SystemAdministrators.current_week())
    stats_text += " | "
    stats_text += Dialogic.VAR.get_variable("version_major")
    stats_text += "."
    stats_text += Dialogic.VAR.get_variable("version_minor")
    stats_text += "."
    stats_text += Dialogic.VAR.get_variable("version_patch")
    stats_text += " | "
    stats_text += Defaults.VERSION_MAJOR
    stats_text += "."
    stats_text += Defaults.VERSION_MINOR
    stats_text += "."
    stats_text += Defaults.VERSION_PATCH
    info["stats"] = stats_text

    extra_info["lines_read"] = Dialogic.VAR.lines_read
    goto_ready()


## Writes and verifies a staging slot, then replaces the destination while retaining its old contents.
## Rechecks battle restrictions before collecting data and before committing the replacement.
func _complete() -> void:
    if _battle_blocks_save():
        return
    if not INTEGRITY.valid_slot_name(slot_name):
        _fail(ERR_FILE_BAD_PATH, "Invalid save slot name.")
        return
    var persistent_data := await SaveAndLoadSystemManager.get_persistent_data()
    if _battle_blocks_save():
        return
    var staging := ".pending-%s-%s" % [slot_name, Time.get_ticks_usec()]
    var error := DirAccess.make_dir_recursive_absolute(Dialogic.Save.get_slot_path(staging))
    if error != OK:
        _fail(error, "Cannot create staging folder.")
        return
    for pair in [["state.txt", Dialogic.get_full_state()], ["game_info", persistent_data], ["info.txt", info]]:
        error = INTEGRITY.write_file(Dialogic.Save, staging, pair[0], pair[1])
        if error != OK:
            _fail(error, "Cannot write " + pair[0] + ". Staging slot: " + staging)
            return
    Dialogic.Save.save_slot_thumbnail(staging)
    error = INTEGRITY.write_manifest(Dialogic.Save, staging)
    if error != OK:
        _fail(error, "Cannot write integrity manifest. Staging slot: " + staging)
        return
    var checked := INTEGRITY.inspect_slot(Dialogic.Save, staging)
    if checked.error != OK:
        failure = checked
        failure.slot = slot_name
        _cancel()
        return
    if _battle_blocks_save():
        return
    var commit := INTEGRITY.commit_slot(Dialogic.Save, staging, slot_name)
    if commit.error != OK:
        _fail(commit.error, "Could not commit staged save: " + str(commit))
        return
    var latest_error := Dialogic.Save.set_latest_slot(slot_name)
    var continue_error := Dialogic.Save.set_global_info("last_hard_save", slot_name)
    if latest_error != OK or continue_error != OK:
        failure = {
            "slot": slot_name,
            "error": latest_error if latest_error != OK else continue_error,
            "errors": ["Save committed, but latest/Continue metadata could not be updated."]
        }
    Dialogic.Save.saved.emit({"slot_name": slot_name, "is_autosave": false})
    goto_completed()
    settled.emit(true)


## Returns false if saving is allowed. Otherwise reports the rejection, marks this task as failed,
## and returns true before any save write is attempted.
func _battle_blocks_save() -> bool:
    var reason := SaveAndLoadSystemManager.get_save_block_reason()
    if reason.is_empty():
        return false
    SaveAndLoadSystemManager.report_save_rejected(reason)
    _fail(ERR_BUSY, reason)
    return true


## Marks this save task failed and wakes its requesting operation.
func _cancel() -> void:
    goto_failed()
    settled.emit(false)


## Stores the reason for a failure before settling the task.
func _fail(error: Error, message: String) -> void:
    failure = {"slot": slot_name, "error": error, "errors": [message, error_string(error)]}
    _cancel()
