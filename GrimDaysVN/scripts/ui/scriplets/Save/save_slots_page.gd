extends Control
#region VARIABLES
## List of slots used by this script.
@export var slots: Array[Control]
## Scene control for prefix options, used to display or change the related setting.
@export var prefix_options: OptionButton
## Scene object used for prefix label.
@export var prefix_label: Label
## Playthrough prefix used to construct the displayed save-slot names.
var current_prefix = ""
## Starting offset used to number the save slots on this page.
var starting_number: int


#region INITIALIZE
## Sets [code]starting_number[/code] to [code](number - 1) * slots.size()[/code].
func on_create(number: int, start_side: String) -> void:
    if slots.is_empty():
        get_slots()

    initialize_page()
    starting_number = (number - 1) * slots.size()
    for x in range(0, slots.size()):
        slot_setup(x)

    if start_side == "Right":
        global_position = Vector2(-1920, 140)
    else:
        global_position = Vector2(1920, 140)


## Sets [code]current_prefix[/code] to [code]Dialogic.VAR.prefix[/code].
func initialize_page() -> void:
    var all_slots: PackedStringArray = _get_existing_prefixes()
    SystemHelpers.set_prefix_if_empty()
    prefix_options.add_item(Dialogic.VAR.prefix)

    _add_existing_prefixes_to_options(all_slots)

    if current_prefix.is_empty():
        current_prefix = Dialogic.VAR.prefix

    _select_current_prefix()


#region PREFIXES
## Collects prefixes from normal five-part save names, ignoring staging, backups and malformed names.
func _get_existing_prefixes() -> PackedStringArray:
    var all_slots: PackedStringArray = PackedStringArray()

    for slot_name in DirAccess.get_directories_at(Dialogic.Save.SAVE_SLOTS_DIR):
        if slot_name.begins_with("."):
            continue
        var split_slot_name = slot_name.split("___")
        if split_slot_name.size() != 5:
            continue
        var prefix = split_slot_name[0] + "___" + split_slot_name[1] + "___" + split_slot_name[2]
        var kind = split_slot_name[3]

        if kind != "Game-Save":
            continue

        if prefix not in all_slots:
            all_slots.append(prefix)

    return all_slots


## Adds the supplied save-prefix choices to the dropdown, skipping the currently active playthrough
## prefix.
func _add_existing_prefixes_to_options(existing_prefixes) -> void:
    for prefix in existing_prefixes:
        if prefix == Dialogic.VAR.prefix:
            continue
        prefix_options.add_item(prefix)


## Selects the latest save's prefix before gameplay, or the current prefix when it matches an
## available dropdown entry.
func _select_current_prefix() -> void:
    var last_used_prefix_split: Array = Dialogic.Save.get_latest_slot().split("___")
    SystemHelpers.print(Dialogic.Save.get_latest_slot())
    var last_prefix = (
        last_used_prefix_split[0] + "___" + last_used_prefix_split[1] + "___" + last_used_prefix_split[2]
        if last_used_prefix_split.size() > 2
        else ""
    )
    SystemHelpers.print(last_prefix)
    for x in range(prefix_options.item_count - 1, -1, -1):
        if last_prefix == prefix_options.get_item_text(x) and GameManager.state == GameManagerStates.STATES.BeforeGame:
            prefix_options.select(x)
            _on_prefix_selection_item_selected(x)
            SystemHelpers.print(x, "old selected.")
            return

        if current_prefix == prefix_options.get_item_text(x):
            SystemHelpers.print(x, "current selected.")
            _on_prefix_selection_item_selected(x)
            prefix_options.select(x)
            return


#region SLOTS
## Finds the save-slot controls belonging to the current page.
func get_slots():
    var child = get_child(0).get_child(0)
    for node in child.get_children():
        if node is Control:
            slots.append(node)


## Builds the numbered slot name from the selected prefix and initializes that slot's display.
func slot_setup(x):
    ##SystemHelpers.print(x)
    var slot_name_to_format = "{prefix}___Game-Save___{number}"
    var slot_name = slot_name_to_format.format({"prefix": current_prefix, "number": starting_number + (x + 1)})
    ##SystemHelpers.print(slot_name)
    slots[x].on_creation(starting_number + (x + 1), slot_name)


## Selects the requested playthrough prefix and rebuilds the page's numbered save-slot entries.
func _on_prefix_selection_item_selected(index: int):
    var prefix_info = prefix_options.get_item_text(index)
    SystemHelpers.print_rich("[b][color=#F00]", prefix_info)
    current_prefix = prefix_info
    prefix_label.update_text(prefix_info)
    for x in range(0, slots.size()):
        slot_setup(x)


#region ANIMATE
## Smoothly changes horizontal position over time. It pauses for [code]tween.tween_property(self,
## "global_position:x", move_to, VNAnimationTimes.STANDARD).finished[/code] before continuing.
func move_right(move_to) -> void:
    var tween = create_tween()
    await tween.tween_property(self, "global_position:x", move_to, VNAnimationTimes.STANDARD).finished


## Smoothly changes horizontal position over time. It pauses for [code]tween.tween_property(self,
## "global_position:x", move_to, VNAnimationTimes.STANDARD).finished[/code] before continuing.
func move_left(move_to) -> void:
    var tween = create_tween()
    await tween.tween_property(self, "global_position:x", move_to, VNAnimationTimes.STANDARD).finished
