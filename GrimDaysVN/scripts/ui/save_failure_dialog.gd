## Shows a local save/load failure report and restores the previous pause/focus state on dismissal.
extends CanvasLayer

## Emitted once when the user dismisses the save/load failure report.
signal acknowledged
## Sanitized report text available for review or copying.
var report_text := ""
## Path of the locally written report, when available.
var report_path := ""
## Save/load operation name displayed by this report.
var operation := "loading"
## Scene-tree pause state restored when the report closes.
var _was_paused := false
## Previously focused control to restore after dismissal.
var _previous_focus: Control
## Prevents repeated dismissal from emitting acknowledgment twice.
var _acknowledged := false


## Builds a modal report without uploading save data.
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 200
    _was_paused = get_tree().paused
    _previous_focus = get_viewport().gui_get_focus_owner()
    get_tree().paused = true
    var shade := ColorRect.new()
    shade.color = Color(0, 0, 0, 0.85)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(shade)
    var panel := PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.set_anchor(SIDE_LEFT, 0.1)
    panel.set_anchor(SIDE_RIGHT, 0.9)
    panel.set_anchor(SIDE_TOP, 0.1)
    panel.set_anchor(SIDE_BOTTOM, 0.9)
    shade.add_child(panel)
    var margin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 20)
    panel.add_child(margin)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 14)
    margin.add_child(box)
    var title := Label.new()
    title.text = "Save is invalid" if operation == "loading" else "Save could not be verified"
    title.add_theme_font_size_override("font_size", 30)
    box.add_child(title)
    var message := Label.new()
    message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message.text = (
        "Loading was cancelled before clearing your current game. The save files were not changed."
        if operation == "loading"
        else "Saving failed. The previous slot has been preserved or retained as a backup. See the report below."
    )
    if operation == "restoring":
        title.text = "Save restoration failed"
        message.text = "An error occurred while applying the checked save. Game state may be partially restored. Please return to the title screen before trying another save." # lint:ignore line-length -- Preserve resource path or authored text.
    elif operation == "metadata":
        title.text = "Save verified — shortcut update failed"
        message.text = "Your save was successfully verified and stored. The Continue shortcut could not be updated; use the save menu to load this slot." # lint:ignore line-length -- Preserve resource path or authored text.
    message.text += "\nPlease submit this report with a description of what happened. Nothing is sent automatically."
    box.add_child(message)
    var details := TextEdit.new()
    details.name = "Report"
    details.editable = false
    details.text = report_text
    details.size_flags_vertical = Control.SIZE_EXPAND_FILL
    details.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    box.add_child(details)
    var status := Label.new()
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status.text = (
        "Report saved to: " + ProjectSettings.globalize_path(report_path)
        if not report_path.is_empty()
        else "Report could not be saved to disk. Use Copy report or select the text above."
    )
    box.add_child(status)
    var buttons := HBoxContainer.new()
    box.add_child(buttons)
    var copy := Button.new()
    copy.text = "Copy bug report"
    copy.pressed.connect(
        func():
            DisplayServer.clipboard_set(report_text)
            copy.text = "Report copied"
    )
    buttons.add_child(copy)
    var okay := Button.new()
    okay.name = "Acknowledge"
    okay.text = "OK — I understand"
    okay.pressed.connect(acknowledge)
    buttons.add_child(okay)
    okay.grab_focus()


## Dismisses once and resumes the operation waiting for acknowledgement.
func acknowledge() -> void:
    if _acknowledged:
        return
    _acknowledged = true
    # Release modal ownership before resuming the awaiting request.
    hide()
    get_tree().paused = _was_paused
    if is_instance_valid(_previous_focus):
        _previous_focus.grab_focus()
    acknowledged.emit()
    queue_free()
