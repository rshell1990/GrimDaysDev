extends Node
#region INVENTORY
## A class to hold items/equipment for a unit or the party.
class_name Inventory
#endregion

## Authored currency item reserved for slot zero.
const COINS_TEMPLATE: ItemTemplate = preload("res://GrimDaysBattle/resources/items/coins.tres")

## Number of ordinary item slots. Slot zero is reserved for currency and is not
## included in this value.
@export_range(1, 1024, 1, "or_greater") var size: int = 1

## Runtime item stacks keyed by slot index. Valid ordinary slots are [code]1[/code]
## through [member size], while slot [code]0[/code] always contains currency.
var slots: Dictionary[int,ItemBase]

## Read-only amount of currency stored in reserved slot zero.
var money: int:
    get:
        var coins: ItemBase = slots.get(0)
        return coins.count if coins else 0


#region INIT
## Tree re-entry must not erase a persistent unit's belongings.
func _enter_tree() -> void:
    initialize()


## Initializes empty storage, including before the owner enters the tree.
func initialize() -> void:
    if slots.is_empty():
        clear_items()


## Explicit new-game/reset operation. Stored items never contribute to Weight.
func clear_items() -> void:
    slots.clear()
    for slot in range(size + 1):
        slots[slot] = null
    slots[0] = ItemBase.create(COINS_TEMPLATE)
    slots[0].count = 0


#endregion


#region MAIN
## Adds an entire stack atomically, filling compatible partial stacks before
## allocating empty slots. Returns [code]false[/code] without changing the
## inventory when the stack is invalid or insufficient capacity is available.
func add_item(item: ItemBase) -> bool:
    initialize()
    if not item or not item.template or item.count < 1:
        return false
    if item.template is EquipmentTemplate and (item.template.stack_size != 1 or _has_instance(item.instance_id)):
        return false
    if item.id == COINS_TEMPLATE.id:
        return add_money(item)
    if _available_capacity(item) < item.count:
        return false

    var remaining: int = item.count
    for slot in range(1, size + 1):
        var stored: ItemBase = slots[slot]
        if not stored or stored.id != item.id or stored.count >= stored.stack_size:
            continue
        var transferred: int = mini(remaining, stored.stack_size - stored.count)
        stored.count += transferred
        remaining -= transferred
        if remaining == 0:
            return true

    for slot in range(1, size + 1):
        if slots[slot]:
            continue
        var stack_count: int = mini(remaining, item.stack_size)
        slots[slot] = ItemBase.create(item.template, stack_count, item.instance_id if item.count == 1 else &"")
        if item.template is EquipmentTemplate:
            slots[slot].ensure_instance_id()
        remaining -= stack_count
        if remaining == 0:
            return true
    return false


## Replaces one ordinary slot with a legal stack. This explicit overwrite path
## is intended for player-confirmed exchanges rather than normal pickups.
func add_item_to_slot(slot: int, item: ItemBase) -> bool:
    initialize()
    if slot < 1 or slot > size or not item or not item.template:
        return false
    if item.id == COINS_TEMPLATE.id or item.count < 1 or item.count > item.stack_size:
        return false
    if item.template is EquipmentTemplate and (item.template.stack_size != 1 or _has_instance(item.instance_id, slot)):
        return false
    slots[slot] = ItemBase.create(item.template, item.count, item.instance_id)
    if item.template is EquipmentTemplate:
        slots[slot].ensure_instance_id()
    return true


## Adds a currency stack to reserved slot zero without inserting it into an
## ordinary item slot.
func add_money(item: ItemBase) -> bool:
    initialize()
    var coins: ItemBase = slots.get(0)
    if not item or item.id != COINS_TEMPLATE.id or item.count < 1 or not coins:
        return false
    if coins.count + item.count > coins.stack_size:
        return false
    coins.count += item.count
    return true


## Item can be an equipable or a consumable, when going to buy things you will try to use the money in slot 0.
func use_item(slot: int, amount: int) -> bool:
    if not slots.has(slot) or not slots[slot] or amount < 1:
        return false
    if not slots[slot].use(amount):
        return false
    if slots[slot].count < 1 and slot != 0:
        slots[slot] = null
        sort_inventory()

    return true


#endregion


## Moves a quantity between inventories without sharing mutable stacks. Capacity
## and source quantity are checked before either side changes; self-transfer fails.
## Production callers use BattlePartyManager.transfer_item to enforce battle locks.
func transfer_to(destination: Inventory, slot: int, amount: int) -> bool:
    if not is_instance_valid(destination) or destination == self or amount < 1:
        return false
    var item: ItemBase = slots.get(slot)
    if not item or item.count < amount:
        return false
    if not destination.add_item(ItemBase.create(item.template, amount, item.instance_id)):
        return false
    return use_item(slot, amount)


## Save-safe records retain slot order and authored identity, never live Resources.
func capture_state() -> Dictionary:
    initialize()
    var records: Array[Dictionary] = []
    for slot in range(1, size + 1):
        var item: ItemBase = slots[slot]
        if item:
            records.append(
                {
                    "slot": slot,
                    "template_id": item.id,
                    "resource_path": item.template.resource_path,
                    "count": item.count,
                    "instance_id": item.instance_id
                }
            )
    return {"size": size, "money": money, "items": records}


## Validates the complete snapshot before replacing any stack. Optional definitions
## support registered/runtime-authored items; disk resources must match the saved ID.
## Whole JSON floats are accepted for integer fields; fractions, booleans and
## nonfinite values are rejected. Malformed records leave this inventory unchanged.
func restore_state(data: Dictionary, definitions: Dictionary = {}) -> PackedStringArray:
    var errors: PackedStringArray = []
    var saved_size: Variant = data.get("size", size)
    var saved_money: Variant = data.get("money", 0)
    var records: Variant = data.get("items", [])
    if not _whole_number(saved_size) or saved_size < 1 or saved_size > 65536:
        return PackedStringArray(["Invalid inventory capacity."])
    if not _whole_number(saved_money) or saved_money < 0 or saved_money > COINS_TEMPLATE.stack_size:
        return PackedStringArray(["Invalid inventory currency."])
    if not records is Array:
        return PackedStringArray(["Invalid inventory item records."])
    var staged: Dictionary[int,ItemBase] = {}
    var instances: Dictionary = {}
    for record in records:
        if not record is Dictionary:
            errors.append("Invalid inventory item record.")
            continue
        var slot: Variant = record.get("slot")
        var count: Variant = record.get("count")
        var template_id: Variant = record.get("template_id")
        var path: Variant = record.get("resource_path", "")
        var instance_id: Variant = record.get("instance_id", &"")
        if not _whole_number(slot) or slot < 1 or slot > saved_size or staged.has(int(slot)):
            errors.append("Invalid or duplicate inventory slot.")
            continue
        if (
            not (template_id is String or template_id is StringName)
            or not path is String
            or not (instance_id is String or instance_id is StringName)
        ):
            errors.append("Invalid inventory item identity.")
            continue
        var definition: ItemTemplate = resolve_definition(StringName(template_id), path, definitions)
        if (
            not definition
            or definition.id == COINS_TEMPLATE.id
            or not _whole_number(count)
            or count < 1
            or count > definition.stack_size
        ):
            errors.append("Unknown item or invalid stack: %s." % template_id)
            continue
        if definition is EquipmentTemplate:
            if definition.stack_size != 1 or String(instance_id).is_empty() or instances.has(StringName(instance_id)):
                errors.append("Equipment must be unstacked with a unique instance ID.")
                continue
            instances[StringName(instance_id)] = true
        staged[int(slot)] = ItemBase.create(definition, int(count), StringName(instance_id))
    if not errors.is_empty():
        return errors
    size = int(saved_size)
    clear_items()
    slots[0].count = int(saved_money)
    for slot in staged:
        slots[slot] = staged[slot]
    return errors


## Accepts finite integer-valued numbers from native or JSON snapshots, not booleans.
static func _whole_number(value: Variant) -> bool:
    return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))


## Resolves item definitions only, never serialized runtime nodes or arbitrary scripts.
static func resolve_definition(id: StringName, path: String, definitions: Dictionary = {}) -> ItemTemplate:
    var definition: ItemTemplate = definitions.get(id) as ItemTemplate
    if not definition:
        for repository: Dictionary in BattleRepository.kinds.values():
            definition = repository.get(id) as ItemTemplate
            if definition:
                break
    if not definition and path.begins_with("res://") and ResourceLoader.exists(path):
        definition = load(path) as ItemTemplate
    return definition if definition and not id.is_empty() and definition.id == id else null


## Prevents the same individual equipment copy from occupying multiple slots.
func _has_instance(instance_id: StringName, except_slot: int = -1) -> bool:
    if instance_id.is_empty():
        return false
    for slot in slots:
        if slot != except_slot and slots[slot] and slots[slot].instance_id == instance_id:
            return true
    return false


#region UTILITY
## Compacts ordinary item stacks toward slot one while preserving their order.
func sort_inventory() -> void:
    var write_slot: int = 1
    for read_slot in range(1, size + 1):
        if not slots[read_slot]:
            continue
        if write_slot != read_slot:
            slots[write_slot] = slots[read_slot]
            slots[read_slot] = null
        write_slot += 1


## Starting from the supplied slot number, loop through the slots, setting the specified slot to the item in the next
## slot.
func shift_all_items_forward_one_slot(start_slot: int) -> void:
    if start_slot < 1 or start_slot > size:
        return
    for y in range(start_slot, size):
        slots[y] = slots[y + 1]
    slots[size] = null


## Checks if the first empty slot is greater than the size of the inventory.
func check_for_full_inventory(first_empty_slot: int) -> bool:
    return first_empty_slot < 1 or first_empty_slot > size


## Loop through the inventory, discarding the start which is reserved for the coins item and then return the first slot
## that is null, the slot number of an existing item that can hold more items, or a slot number larger than the size of
## the inventory.
func find_empty_slot_or_item(item: ItemBase) -> int:
    if item:
        for x in range(1, size + 1):
            var stored: ItemBase = slots[x]
            if stored and stored.id == item.id and stored.count < stored.stack_size:
                return x

    for x in range(1, size + 1):
        if not slots[x]:
            return x

    return size + 1


## Calculates how many more copies of [param item] can fit without mutating the
## inventory. Existing compatible stacks and empty slots both contribute.
func _available_capacity(item: ItemBase) -> int:
    var capacity: int
    for slot in range(1, size + 1):
        var stored: ItemBase = slots[slot]
        if not stored:
            capacity += item.stack_size
        elif stored.id == item.id:
            capacity += maxi(stored.stack_size - stored.count, 0)
    return capacity
#endregion
