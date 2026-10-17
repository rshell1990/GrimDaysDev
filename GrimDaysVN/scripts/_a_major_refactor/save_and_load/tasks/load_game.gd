extends Task
## Queued operation for reading a normal save slot and restoring its game state.
class_name TaskLoadGame
## Completion of this specific load, not the whole queue.
signal settled(success: bool)
## Preflight-validated Dialogic state, read once before the live game changes.
var checked_state: DialogicSaveState
## Name identifying the save slot this operation uses.
var slot_name
## Lookup table for loaded state; keys select the corresponding stored values.
var loaded_state: Dictionary = {}


## Receives the exact payloads already validated by the manager.
func _init(task_name: StringName, sent_slot_name: String, checked: Dictionary) -> void:
    super(task_name)
    slot_name = sent_slot_name
    loaded_state = checked.game_info
    checked_state = checked.state


## Clears [code]Dialogic[/code]; sets [code]Dialogic.paused[/code] to true; sets
## [code]Dialogic.Inputs.auto_skip.enabled[/code] to false. It pauses for
## [code]Dialogic.timeline_ended[/code] before continuing.
func _prepare() -> void:
    if Dialogic.current_timeline != null:
        GameManager.on_loading_sequence_start()
        Dialogic.end_timeline()
        await Dialogic.timeline_ended
        Dialogic.clear()
    CustomLogger.warn(self, self._prepare, " is pausing Dialogic.", CustomLogger.LEVEL.VERBOSE)
    Dialogic.paused = true
    SoundManager.stop_music()
    SoundManager.stop_all_ambient_sounds()

    Dialogic.Text.hide_textbox(true)
    Dialogic.Inputs.auto_skip.enabled = false
    goto_ready()


## Restores checked local state and awaits Dialogic restoration before reporting success.
## This Dialogic version returns void, so it cannot report a post-preflight restoration error.
func _complete() -> void:
    await SaveAndLoadSystemManager.restore_data(loaded_state)
    await Dialogic.load_full_state(checked_state)
    Dialogic.Save.set_latest_slot(slot_name)
    goto_completed()
    settled.emit(true)


## Marks the load failed and wakes its requesting operation.
func _cancel() -> void:
    goto_failed()
    settled.emit(false)
