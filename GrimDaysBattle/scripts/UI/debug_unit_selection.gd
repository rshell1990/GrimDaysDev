# Editor configuration for DebugUnitSelection.
@tool
extends Control
## Controls the debug unit selection presentation used by the battle interface.
class_name DebugUnitSelection

@export_category("Allies")
## Configures the selected allies display used by this debug unit selection.
@export var selected_allies_display: Control
## Configures the selectable allies display used by this debug unit selection.
@export var selectable_allies_display: Control

@export_category("Foes")
## Configures the selected foes display used by this debug unit selection.
@export var selected_foes_display: Control
## Configures the selectable foes display used by this debug unit selection.
@export var selectable_foes_display: Control

@export_category("Unit Templates")
## Configures the selected unit display template used by this debug unit selection.
@export var selected_unit_display_template: PackedScene
## Configures the selectable unit display template used by this debug unit selection.
@export var selectable_unit_display_template: PackedScene
## Configures the available templates used by this debug unit selection.
@export var available_templates: ResourceTemplates
@export_category("Other")
## Configures the start button used by this debug unit selection.
@export var start_button: Button

## Ordered runtime collection of selected allies.
var selected_allies: Array[BattleUnitTemplate]
## Ordered runtime collection of selected foes.
var selected_foes: Array[BattleUnitTemplate]


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    for index in range(selectable_allies_display.get_child_count(), -1, -1):
        if selectable_allies_display.get_child_count() > 0:
            selectable_allies_display.get_child(index).queue_free()
        if selectable_foes_display.get_child_count() > 0:
            selectable_foes_display.get_child(index).queue_free()

    for x in range(0, available_templates.all.size()):
        var selectable_ally = selectable_unit_display_template.instantiate()
        var new_ally_panel = Panel.new()
        new_ally_panel.set_deferred("size", Vector2(64, 64))
        selectable_allies_display.add_child(new_ally_panel)
        new_ally_panel.add_child(selectable_ally)
        selectable_ally.setup(available_templates.all[x])
        selectable_ally.add.connect(add_to_allies)

        var selectable_foe = selectable_unit_display_template.instantiate()
        var new_foe_panel = Panel.new()
        selectable_foes_display.add_child(new_foe_panel)
        new_foe_panel.set_deferred("size", Vector2(64, 64))
        new_foe_panel.add_child(selectable_foe)
        selectable_foe.setup(available_templates.all[x])
        selectable_foe.add.connect(add_to_foes)

    start_button.button_up.connect(on_start_pressed)


## Updates debug unit selection state for the current frame.
func _physics_process(_delta: float) -> void:
    if start_button.disabled:
        if (
            (not selected_allies.is_empty() and not is_all_null(selected_allies))
            and (not selected_foes.is_empty() and not is_all_null(selected_foes))
        ):
            start_button.disabled = false
    else:
        if is_all_null(selected_allies) or is_all_null(selected_foes):
            start_button.disabled = true


## Returns whether all null.
func is_all_null(unit_list: Array) -> bool:
    var array_size: int = unit_list.size()
    var nulls_found: int = 0
    for x in range(0, array_size):
        if unit_list[x] == null:
            nulls_found += 1

    if nulls_found == array_size:
        return true

    return false


## Adds to allies for this debug unit selection.
func add_to_allies(id: StringName) -> void:
    if not check_for_open_slot(selected_allies):
        return
    CustomLogger.hint(self, add_to_allies, "Adding %s to allies." % id, CustomLogger.LEVEL.VERBOSE)
    var template = BattleRepository.get_info(BattleRepository.BATTLE_UNIT_TEMPLATES, id)

    var current_index = find_empty_slot(selected_allies_display)

    if current_index == -9999:
        return

    var selected_unit_display = selected_unit_display_template.instantiate()
    selected_allies_display.get_child(current_index).add_child(selected_unit_display)
    selected_unit_display.setup(template)
    selected_unit_display.index = current_index
    selected_unit_display.remove.connect(on_ally_remove)
    if selected_allies.size() > current_index:
        selected_allies[current_index] = template
    else:
        selected_allies.append(template)


## Handles the ally remove notification for this debug unit selection.
func on_ally_remove(index: int) -> void:
    selected_allies_display.get_child(index).get_child(0).queue_free()
    selected_allies[index] = null


## Adds to foes for this debug unit selection.
func add_to_foes(id: StringName) -> void:
    if not check_for_open_slot(selected_foes):
        return
    CustomLogger.hint(self, add_to_foes, "Adding %s to foes." % id, CustomLogger.LEVEL.VERBOSE)
    var template = BattleRepository.get_info(BattleRepository.BATTLE_UNIT_TEMPLATES, id)

    var current_index = find_empty_slot(selected_foes_display)
    if current_index == -9999:
        return
    var selected_unit_display = selected_unit_display_template.instantiate()
    selected_foes_display.get_child(current_index).add_child(selected_unit_display)
    selected_unit_display.setup(template)
    selected_unit_display.index = current_index
    selected_unit_display.remove.connect(on_foe_remove)
    if selected_foes.size() > current_index:
        selected_foes[current_index] = template
    else:
        selected_foes.append(template)


## Handles the foe remove notification for this debug unit selection.
func on_foe_remove(index: int) -> void:
    selected_foes_display.get_child(index).get_child(0).queue_free()
    selected_foes[index] = null


## Finds and returns empty slot for this debug unit selection.
func find_empty_slot(display_holder) -> int:
    for x in range(0, display_holder.get_child_count()):
        if not display_holder.get_child(x).get_child_count():
            return x

    return -9999


## Checks for open slot for this debug unit selection.
func check_for_open_slot(unit_list: Array) -> bool:
    var has_open: bool = true

    if unit_list.size() > 3:
        has_open = false

    for unit in unit_list:
        if not unit:
            has_open = true
            break

    return has_open


## Handles the start pressed notification for this debug unit selection.
func on_start_pressed() -> void:
    BattleController.go_to_next_phase({"allies": selected_allies, "foes": selected_foes})
    visible = false
    process_mode = Node.PROCESS_MODE_DISABLED
