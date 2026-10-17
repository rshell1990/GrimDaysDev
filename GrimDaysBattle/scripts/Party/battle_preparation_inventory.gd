extends VBoxContainer
## Binds the framework's inventory grids and equipment slots to party services.
## Every menu command retains the rendering generation and exact item identity.
class_name BattlePreparationInventory

## Emitted after an inventory command with whether the party accepted it.
signal operation_finished(success: bool)

## Scene used to display each personal or shared inventory slot.
const SLOT_SCENE := preload("res://GrimDaysBattle/scenes/ui/party_inventory_slot.tscn")
## Maps silhouette slot labels to runtime equipment-slot IDs.
const EQUIPMENT_SLOTS := {
    "Left Hand": UnitEquipmentSlot.SLOT.LeftHand,
    "Right Hand": UnitEquipmentSlot.SLOT.RightHand,
    "Left Ring": UnitEquipmentSlot.SLOT.LeftRing,
    "Right Ring": UnitEquipmentSlot.SLOT.RightRing,
    "Neck": UnitEquipmentSlot.SLOT.Neck,
    "Chest": UnitEquipmentSlot.SLOT.Chest,
    "Hands": UnitEquipmentSlot.SLOT.Hands,
}
## Party service authorizing transfers and equipment changes.
var party: BattlePartyManager
## Stable ID of the unit whose personal inventory is displayed.
var unit_id: StringName
## Invalidates callbacks captured before a refresh or dismissal.
var _generation: int = 0
## Maps popup command IDs to generation-checked inventory operations.
var _commands: Dictionary[int, Callable] = {}
## Monotonic command ID so stale menu selections cannot invoke replacement commands.
var _next_command_id: int = 0
## Container for shared-inventory slot controls.
@onready var stash_slots: GridContainer = %"Stash Slots"
## Container for the selected unit's inventory slots.
@onready var personal_slots: HBoxContainer = %PersonalSlots
## Popup offering transfer, equip and unequip commands.
@onready var item_actions: PopupMenu = %ItemActions
## Displays money.
@onready var inventory_status: Label = %InventoryStatus



## Connects popup-menu selections to their saved commands.
func _ready() -> void:
    item_actions.id_pressed.connect(_execute_command)


## Selects the party and unit whose inventory will be shown, then refreshes the display.
func present(manager: BattlePartyManager, selected_id: StringName) -> void:
    party = manager
    unit_id = selected_id
    refresh()


## Invalidates old menu commands, hides the popup and stops this view from processing input.
func dismiss() -> void:
    _generation += 1
    _commands.clear()
    item_actions.hide()
    party = null
    process_mode = Node.PROCESS_MODE_DISABLED


## Rebuilds shared and personal item slots, equipment buttons, money and equipped-weight
## information. Old buttons can no longer change items.
func refresh() -> void:
    _generation += 1
    _commands.clear()
    item_actions.hide()
    BattlePreparationPanel._clear(stash_slots)
    BattlePreparationPanel._clear(personal_slots)
    if not is_instance_valid(party):
        return
    var unit: BattleUnit = party.runtime_units.get(unit_id)
    if not unit:
        return
    _inventory(party.stash, &"", unit_id, stash_slots)
    _inventory(unit.inventory, unit_id, &"", personal_slots)
    inventory_status.text = "Coins: %s " % [party.stash.money + unit.inventory.money]
    var silhouette := get_parent().get_node("Character Management/Equpment and Stats/Character Silouhette")
    for slot_name in EQUIPMENT_SLOTS:
        var slot_id: int = EQUIPMENT_SLOTS[slot_name]
        var equipment_slot := unit.get_equipment_slot(slot_id)
        var equipped: Equipable = equipment_slot.equipped if equipment_slot else null
        var display := silhouette.get_node(slot_name + " Slot") as TextureRect
        display.visible = equipment_slot != null
        var icon := display.get_node("Frame") as TextureRect
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.texture = equipped.template.icon if equipped else null
        var button := display.get_node("Select") as Button
        button.tooltip_text = slot_name + ": " + (equipped.template.display_name if equipped else "Empty")
        button.disabled = equipped == null
        for connection in button.pressed.get_connections():
            button.pressed.disconnect(connection.callable)
        var generation := _generation
        var selected_id := unit_id
        button.pressed.connect(
            func():
                if not _current(generation):
                    return
                _begin_menu()
                _add_command(
                    "Unequip",
                    func() -> bool:
                        return (
                            is_instance_valid(equipment_slot)
                            and equipment_slot.equipped == equipped
                            and party.unequip_inventory_item(selected_id, slot_id)
                        )
                )
                _popup(button)
        )


## Creates item-slot buttons for one inventory and offers valid transfer or equip commands for the
## exact displayed stack.
func _inventory(inventory: Inventory, owner_id: StringName, destination: StringName, grid: Container) -> void:
    var generation := _generation
    for slot in range(1, inventory.size + 1):
        var item: ItemBase = inventory.slots.get(slot)
        var cell := SLOT_SCENE.instantiate() as Control
        grid.add_child(cell)
        var button := cell.get_node("Select") as Button
        button.disabled = item == null
        cell.set_meta(&"inventory_slot", slot)
        if not item:
            button.tooltip_text = "Empty slot"
            continue
        cell.get_node("Icon").texture = item.template.icon
        cell.get_node("Count").text = str(item.count) if item.count > 1 else ""
        button.text = "" if item.template.icon else item.template.display_name.left(7)
        button.tooltip_text = (
            "%s ×%s\n%s\nClick to transfer or equip."
            % [item.template.display_name, item.count, item.template.description]
        )
        button.pressed.connect(
            func():
                if not _current(generation) or inventory.slots.get(slot) != item:
                    return
                _begin_menu()
                var transfer := "To unit" if owner_id.is_empty() else "To stash"
                _add_command(
                    transfer + " (1)",
                    func() -> bool:
                        return inventory.slots.get(slot) == item and party.transfer_item(owner_id, destination, slot)
                )
                if item.count > 1:
                    var count: int = item.count
                    _add_command(
                        transfer + " (all)",
                        func() -> bool:
                            return (
                                inventory.slots.get(slot) == item
                                and party.transfer_item(owner_id, destination, slot, count)
                            )
                    )
                if owner_id == unit_id and item.template is EquipmentTemplate:
                    for equip_slot: int in item.template.equips_to:
                        _add_command(
                            "Equip: " + String(UnitEquipmentSlot.TYPES[equip_slot]),
                            func() -> bool:
                                return (
                                    inventory.slots.get(slot) == item
                                    and party.equip_inventory_item(owner_id, slot, equip_slot)
                                )
                        )
                _popup(button)
        )


## Checks that a menu command belongs to the latest display and the party still allows preparation.
func _current(generation: int) -> bool:
    return generation == _generation and is_instance_valid(party) and party.can_prepare_inventory()


## Clears the previous popup items and saved commands.
func _begin_menu() -> void:
    item_actions.clear()
    _commands.clear()


## Adds a popup action that checks the display version before running, refreshes the view and
## reports success or failure.
func _add_command(title: String, operation: Callable) -> void:
    var generation := _generation
    var command_id := _next_command_id
    _next_command_id += 1
    item_actions.add_item(title, command_id)
    _commands[command_id] = func():
        if not _current(generation):
            return
        var success: bool = operation.call()
        refresh()
        operation_finished.emit(success)


## Opens the action menu below the clicked control.
func _popup(button: Control) -> void:
    item_actions.reset_size()
    item_actions.position = Vector2i(button.get_screen_position() + Vector2(0, button.size.y))
    item_actions.popup()


## Runs the saved command for a selected menu ID when it still exists.
func _execute_command(index: int) -> void:
    if _commands.has(index):
        var command := _commands[index]
        command.call()
