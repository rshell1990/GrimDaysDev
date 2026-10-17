extends Control

## Image used for screenshot.
@export var screenshot_texture: TextureRect
## Scene object used for date label.
@export var date_label: Label
## Scene object used for save name label.
@export var save_name_label: Label
## Scene object used for save stats label.
@export var save_stats_label: Label

## Button used for save button.
@export var save_button: Button
## Button used for load button.
@export var load_button: Button
## Button used for delete button.
@export var delete_button: Button

## Scene object used for bg panel.
@export var bg_panel: Panel
## Scene object used for frame panel.
@export var frame_panel: Panel
## Scene object used for screenshot frame panel.
@export var screenshot_frame_panel: Panel

## Notification for loaded. Supplies [code]data[/code] to connected functions.
signal loaded(data)
## Number shown for this save slot within the save interface.
var slot_number: int
## Name identifying the save slot this operation uses.
var slot_name: String
## Save label entered by the player.
var player_input_name: String = "Default."
## Game version recorded when this playthrough began.
var slot_original_version: String
## Game version recorded when this slot was last saved.
var slot_current_version: String

## Saved-state dictionary shared by the save-slot controls.
static var loaded_state: Dictionary = {}

## Object associated with the current text-entry request, used to match the reply to its requester.
var input_caller: Variant = null


## When the node is ready, this function connects responses to
## [code]VNSignalBus.on_ui_update[/code], [code]DDTextInput.input_confirmed[/code],
## [code]DDTextInput.input_shown[/code]; sets [code]save_button.disabled[/code] to true; sets
## [code]save_button.process_mode[/code] to [code]Node.PROCESS_MODE_DISABLED[/code].
func _ready() -> void:
    VNSignalBus.on_ui_update.connect(set_color)
    DDTextInput.input_confirmed.connect(on_input)
    DDTextInput.input_shown.connect(on_input_shown)
    if GameManager.state == GameManagerStates.STATES.BeforeGame:
        save_button.disabled = true
        save_button.process_mode = Node.PROCESS_MODE_DISABLED


## Remembers which text-input request belongs to this control.
func on_input_shown(data: Dictionary) -> void:
    input_caller = data.caller


## Handles the submitted text only for the matching input requester and applies it to this save
## control.
func on_input(input: String) -> void:
    if str(input_caller) != str(self):
        ##SystemHelpers.print("Caller: ", input_caller, " does not match ", self)
        return

    player_input_name = input


## Currently performs no work; this function is a placeholder for behavior supplied later or by a
## child script.
func set_color() -> void:
    #SystemHelpers.color_self(bg_panel, frame_panel)
    pass


## Sets [code]slot_number[/code] to [code]number[/code]; sets [code]slot_name[/code] to
## [code]given_slot_name[/code].
func on_creation(number: int, given_slot_name: String = "") -> void:
    ##SystemHelpers.print("Creating Slot: ", number, given_slot_name)
    slot_number = number
    set_color()
    SystemHelpers.set_prefix_if_empty()
    slot_name = given_slot_name

    if not Dialogic.Save.has_slot(slot_name):
        disable_slot()
    else:
        enable_slot()
    SystemHeadquarters.listen_for(loaded, SystemHeadquarters._on_load)
    VNSignalBus.listen_for(loaded, VNSignalBus._on_load)


## Confirms overwrite and requests a save name without deleting the existing slot.
## Awaits the verified save result before enabling or refreshing the slot; battle guards still apply.
func _on_save_pressed() -> void:
    var block_reason := SaveAndLoadSystemManager.get_save_block_reason()
    if not block_reason.is_empty():
        SaveAndLoadSystemManager.report_save_rejected(block_reason)
        return
    SystemHelpers.set_prefix_if_empty()
    var info: Dictionary = {}
    if Dialogic.Save.has_slot(slot_name):
        ConfirmationModal.customize("Overwrite this save?", "This will erase the old save file.", "Yes", "No")

        var confirmed = await ConfirmationModal.prompt(true)

        if not confirmed:
            return

    DDTextInput.show_input(
        "Name your save game:",
        self,
        Time.get_datetime_string_from_system(),
        Time.get_datetime_string_from_system(),
        true
    )
    UIDirector.show_text_input()
    GameManager.change_state(GameManagerStates.STATES.Input)
    await DDTextInput.input_confirmed
    input_caller = null
    DDTextInput.hide_text_input()
    GameManager.restore_last_state_on_end()

    if not await SaveAndLoadSystemManager.save_game(slot_name, player_input_name):
        return

    enable_slot()


## Requests loading; the manager validates before changing the menu or running game.
func _on_load_pressed() -> void:
    SaveAndLoadSystemManager.load_game(slot_name)


## Deletes this save slot and updates its display to the disabled/empty state.
func _on_delete_pressed() -> void:
    Dialogic.Save.delete_slot(slot_name)
    disable_slot()


## Changes this slot's controls and text to represent an empty or unavailable save.
func disable_slot():
    if screenshot_texture.texture != null:
        var texture_size = screenshot_texture.texture.get_size()
        screenshot_texture.texture = ImageTexture.create_from_image(
            Image.create(texture_size.x, texture_size.y, false, Image.FORMAT_RGB8)
        )
        screenshot_texture.self_modulate = Color.BLACK
        screenshot_texture.self_modulate.a = 0.8
    load_button.disabled = true
    delete_button.disabled = true
    date_label.visible = true
    save_name_label.visible = true
    save_stats_label.visible = false
    save_name_label.text = "Empty slot: #" + str(slot_number)
    date_label.text = ""


## Enables this slot's controls for an existing save.
func enable_slot():
    read_info_to_slot()
    screenshot_texture.self_modulate = Color.WHITE
    screenshot_texture.self_modulate.a = 1.0
    load_button.disabled = false
    delete_button.disabled = false
    date_label.visible = true
    save_name_label.visible = true
    save_stats_label.visible = true
    var split_slot_name = slot_name.split("___")
    var prefix = "___".join(split_slot_name.slice(0, 3)) if split_slot_name.size() >= 5 else ""
    if prefix != Dialogic.VAR.prefix:
        save_button.disabled = true


## Displays checked metadata with fallback labels for damaged or missing fields.
## Short statistics strings do not prevent the save menu from opening.
func read_info_to_slot() -> void:
    ##SystemHelpers.print("Reading info to slot.")
    screenshot_texture.texture = Dialogic.Save.get_slot_thumbnail(slot_name)
    var read := SaveAndLoadSystemManager.INTEGRITY.read_file(Dialogic.Save, slot_name, "info.txt")
    var info: Dictionary = read.get("data", {}) if read.get("data") is Dictionary else {}
    slot_original_version = ""
    slot_current_version = ""
    if not info.get("date") is Dictionary or not info.get("stats") is String:
        show_invalid_metadata()
        return
    for key in ["hour", "minute", "second", "month", "day", "year"]:
        if not info.date.get(key) is int:
            show_invalid_metadata()
            return
    var hour = info.date.hour
    var am_pm_divide: int = 12
    var twelve_hour_suffix: String = "AM"
    if hour >= am_pm_divide:
        twelve_hour_suffix = "PM"

    info.date.hour = hour % am_pm_divide
    info.date.hour = info.date.hour if info.date.hour != Basics.FIRST else am_pm_divide
    info.date["twelve_hour_suffix"] = twelve_hour_suffix
    var label_text: String = "{month}/{day}/{year} - {hour}:{minute}:{second} {twelve_hour_suffix}"

    date_label.text = label_text.format(info.date)
    if info.has("save_name"):
        save_name_label.text = str(info.save_name)
    else:
        save_name_label.text = str(info.get("called", "Unnamed save"))

    var stat_text: PackedStringArray = info.stats.split("|")
    var other_stat_text = stat_text.slice(0, 5)
    var correct_stat_text: String = ""
    for text in other_stat_text:
        if "Week" in text:
            continue
        correct_stat_text += text
        correct_stat_text += " | "

    if stat_text.size() >= 2:
        slot_original_version = stat_text[-2]
        slot_current_version = stat_text[-1]

    save_stats_label.text = correct_stat_text


## Returns version details for the save slot's tooltip, or empty header and description strings if
## its original version is unknown.
func get_custom_tooltip() -> Dictionary:
    var tooltip_info: Dictionary = {}

    if slot_original_version != "":
        tooltip_info["header"] = "Version Details"
        tooltip_info["description"] = "Began In: " + slot_original_version + " \n"
        tooltip_info["description"] += "Last Saved In: " + slot_current_version + " \n"

    else:
        tooltip_info["header"] = ""
        tooltip_info["description"] = ""
    return tooltip_info


## Keeps damaged metadata from breaking the save menu; loading performs full validation.
func show_invalid_metadata() -> void:
    date_label.text = "Save metadata unavailable"
    save_name_label.text = "Slot #" + str(slot_number)
    save_stats_label.text = "Load to validate this save and generate a report."
