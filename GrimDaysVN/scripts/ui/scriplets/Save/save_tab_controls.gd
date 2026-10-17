extends HBoxContainer

## Save-page number currently selected in the interface.
var current_page: int = 1
## Scene object used for current save page.
var current_save_page: Control
## Object associated with the current text-entry request, used to match the reply to its requester.
var input_caller: Variant = null
## Whether on main menu is currently enabled or true.
var on_main_menu: bool = false
## Notification for on input finished. Supplies [code]signal_sent[/code], [code]menu[/code] to
## connected functions.
signal on_input_finished(signal_sent, menu)
## Scene object used for current page label.
@export var current_page_label: Label
## Scene template used to create save page template.
@export var save_page_template: PackedScene
## Scene object used for root.
@export var root: Control


# Called when the node enters the scene tree for the first time.
## When the node is ready, this function connects responses to
## [code]Dialogic.TextInput.input_confirmed[/code], [code]Dialogic.TextInput.input_shown[/code].
func _ready():
    Dialogic.TextInput.input_confirmed.connect(on_input)
    Dialogic.TextInput.input_shown.connect(on_input_shown)


## Remembers which text-input request belongs to this control.
func on_input_shown(data: Dictionary) -> void:
    input_caller = data.caller


## Handles the submitted text only for the matching input requester and applies it to this save
## control.
func on_input(input) -> void:
    %LocalSignalBus.listen_for(on_input_finished, %LocalSignalBus._on_sub_function_finished)
    if str(input_caller) != str(self):
        ##SystemHelpers.print("Not me: ", input_caller, " I am: ", self)
        return

    var split_input = []
    for char_ in input:
        split_input.append(char_)
    if Basics.ALPHABET in split_input:
        return

    var original_page_number = current_page
    var original_save_page = current_save_page
    current_page = clampi(input.to_int(), 1, 1000000)
    current_page_label.text = "Current Page: " + str(current_page)

    var new_save_page = save_page_template.instantiate()

    var direction = "Left" if current_page >= original_page_number else "Right"
    new_save_page.on_create(current_page, direction)

    if direction == "Left":
        move_left(new_save_page, original_save_page)
    else:
        move_right(new_save_page, original_save_page)

    current_save_page = new_save_page
    input_caller = null

    on_input_finished.emit(self)


## Sets [code]current_page[/code] to [code]clampi(current_page + 1, 1, 1000000)[/code]; sets
## [code]current_page_label.text[/code] to [code]"Current Page: " + str(current_page)[/code]; sets
## [code]new_save_page.current_prefix[/code] to [code]original_prefix[/code].
func _on_increase_page_number_pressed() -> void:
    if current_page + 1 > 1000000:
        return

    var original_save_page = current_save_page
    var original_prefix = original_save_page.current_prefix
    var new_save_page = save_page_template.instantiate()
    var direction = "Left"

    current_page = clampi(current_page + 1, 1, 1000000)
    current_page_label.text = "Current Page: " + str(current_page)
    new_save_page.current_prefix = original_prefix
    new_save_page.on_create(current_page, direction)
    move_left(new_save_page, original_save_page)

    current_save_page = new_save_page
    ##SystemHelpers.print("INCREASE")


## Sets [code]current_page_label.text[/code] to [code]"Current Page: " + str(current_page)[/code].
## It pauses for [code]Dialogic.TextInput.input_confirmed[/code] before continuing.
func _on_page_selection_pressed() -> void:
    DDTextInput.show_input("Type the page number you wish to go to. (Max 1,000,000)", self)
    await Dialogic.TextInput.input_confirmed
    current_page_label.text = "Current Page: " + str(current_page)
    Dialogic.TextInput.hide_text_input()


## Sets [code]current_page[/code] to [code]clampi(current_page - 1, 1, 1000000)[/code]; sets
## [code]current_page_label.text[/code] to [code]"Current Page: " + str(current_page)[/code]; sets
## [code]new_save_page.current_prefix[/code] to [code]original_prefix[/code].
func _on_decrease_page_number_pressed() -> void:
    if current_page - 1 < 1:
        return

    var original_save_page = current_save_page
    var original_prefix = original_save_page.current_prefix
    var new_save_page = save_page_template.instantiate()
    var direction = "Right"

    current_page = clampi(current_page - 1, 1, 1000000)
    current_page_label.text = "Current Page: " + str(current_page)
    new_save_page.current_prefix = original_prefix
    new_save_page.on_create(current_page, direction)
    move_right(new_save_page, original_save_page)
    ##SystemHelpers.print("DECREASE")
    current_save_page = new_save_page


## Adds [code]new_save_page[/code] as a child of [code]root[/code]; schedules
## [code]original_save_page[/code] for deletion. It pauses for
## [code]original_save_page.move_left(-1920)[/code] before continuing.
func move_left(new_save_page, original_save_page) -> void:
    root.add_child(new_save_page)
    ##SystemHelpers.print("LEFT")
    ##SystemHelpers.print("NEW SPP: ", new_save_page.position)
    new_save_page.move_right(0)
    if original_save_page != null:
        #SystemHelpers.print("Original SPP: ", original_save_page.position)
        await original_save_page.move_left(-1920)
        original_save_page.queue_free()


## Adds [code]new_save_page[/code] as a child of [code]root[/code]; schedules
## [code]original_save_page[/code] for deletion. It pauses for
## [code]original_save_page.move_right(1920)[/code] before continuing.
func move_right(new_save_page, original_save_page) -> void:
    root.add_child(new_save_page)
    ##SystemHelpers.print("RIGHT")
    ##SystemHelpers.print("NEW SPP: ", new_save_page.position)
    new_save_page.move_left(0)
    if original_save_page != null:
        #SystemHelpers.print("Original SPP: ", original_save_page.position)
        await original_save_page.move_right(1920)
        original_save_page.queue_free()
