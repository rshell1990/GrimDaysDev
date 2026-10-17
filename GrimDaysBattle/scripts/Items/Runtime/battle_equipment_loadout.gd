extends RefCounted
## Builds and saves equipped loadouts, and exchanges individually owned inventory
## equipment. Production preparation callers use the party service's encounter lock.
class_name BattleEquipmentLoadout


## Validates before mutation, then swaps synchronously. A displaced item occupies
## the incoming item's inventory slot, so a full backpack still permits exchanges.
## Inventory ownership is settled before OnEquip can emit signals or run effects.
static func equip_from_inventory(unit: BattleUnit, inventory_slot: int, slot_id: int) -> bool:
    if not is_instance_valid(unit) or not unit.inventory or not unit.is_inside_tree():
        return false
    var item: ItemBase = unit.inventory.slots.get(inventory_slot)
    var slot := _slot(unit, slot_id)
    if not item or not item.template is EquipmentTemplate or item.count != 1 or item.instance_id.is_empty():
        return false
    if not slot or not slot.can_equip(item.template) or item.template.weight < 0:
        return false
    for equipped_record in capture(unit):
        if equipped_record.instance_id == item.instance_id:
            return false
    var previous: Equipable = slot.equipped
    if previous and unit.inventory._has_instance(previous.item_instance_id):
        return false
    var returned: ItemBase = ItemBase.create(previous.template, 1, previous.item_instance_id) if previous else null
    unit.inventory.slots[inventory_slot] = returned
    unit.inventory.sort_inventory()
    slot.clear_equipment()
    slot.template_id = item.id
    slot.spawn_equipment(item.template, item.instance_id)
    return true


## Unequip fails intact when there is no inventory capacity. Revokes grants once,
## and retains the individual item's identity for later transfers/re-equipping.
static func unequip_to_inventory(unit: BattleUnit, slot_id: int) -> bool:
    if not is_instance_valid(unit) or not unit.inventory or not unit.is_inside_tree():
        return false
    var slot := _slot(unit, slot_id)
    if not slot or not slot.equipped is Equipable:
        return false
    var item: Equipable = slot.equipped
    if not unit.inventory.add_item(ItemBase.create(item.template, 1, item.item_instance_id)):
        return false
    slot.clear_equipment()
    return true


## Authored collection order chooses the first free compatible slot. Reject the
## whole starting loadout if any item cannot be placed; never silently displace.
static func plan_starting(template: BattleUnitTemplate) -> Dictionary:
    var entries: Array[Dictionary] = []
    var errors := PackedStringArray()
    var occupied: Dictionary = {}
    if not template.equipment:
        return {"entries": entries, "errors": errors}
    for item in template.equipment.all:
        if not item or item.id.is_empty() or item.weight < 0 or item.stack_size != 1:
            errors.append("Starting equipment requires a valid ID, non-negative weight and stack size one.")
            continue
        var selected: int = -1
        for slot in item.equips_to:
            if UnitEquipmentSlot.TYPES.has(slot) and not occupied.has(slot):
                selected = slot
                break
        if selected < 0:
            errors.append("No free compatible slot for starting item %s." % item.id)
            continue
        occupied[selected] = true
        entries.append({"slot": selected, "template": item})
    return {"entries": entries, "errors": errors}


## Called before the new unit enters the tree. Item _ready applies grants after
## the effects manager/slots have entered, without replacing permanent units.
static func stage_starting(unit: BattleUnit) -> void:
    var plan := plan_starting(unit.template_resource)
    for entry in plan.entries:
        var slot := _slot(unit, entry.slot)
        if slot:
            slot.template_id = entry.template.id
            slot.add_child(Equipable.create(entry.template))


## Preserve weapon override precedence, not merely slot-enum order.
static func capture(unit: BattleUnit) -> Array[Dictionary]:
    var items: Array[Equipable] = []
    for child in unit.get_children():
        if child is UnitEquipmentSlot and child.equipped is Equipable:
            items.append(child.equipped)
    items.sort_custom(
        func(a: Equipable, b: Equipable):
            return (
                unit._basic_action_override_order.find(a.get_instance_id())
                < unit._basic_action_override_order.find(b.get_instance_id())
            )
    )
    var records: Array[Dictionary] = []
    for item in items:
        records.append(
            {
                "slot": item.get_parent().slot,
                "template_id": item.template.id,
                "resource_path": item.template.resource_path,
                "instance_id": item.item_instance_id
            }
        )
    return records


## Validate all records before mutation. Reconstruct grants synchronously before
## the party restores pools/cooldowns; never replay one-shot OnEquip operations.
## Definitions may be registered, part of this unit's starting loadout, or an
## authored resource whose path and ID both match the saved identity.
static func restore(unit: BattleUnit, records: Array) -> PackedStringArray:
    var errors := PackedStringArray()
    var prepared: Array[Dictionary] = []
    var slots: Dictionary = {}
    var instances: Dictionary = {}
    for record in records:
        if record is not Dictionary:
            errors.append("Invalid equipment record.")
            continue
        if (
            record.get("slot") is not int
            or not (
                (record.get("instance_id") is String or record.get("instance_id") is StringName)
                and (record.get("template_id") is String or record.get("template_id") is StringName)
                and record.get("resource_path", "") is String
            )
        ):
            errors.append("Equipment identity or slot has an invalid type.")
            continue
        var slot_id: int = record.get("slot", -1)
        var slot := _slot(unit, slot_id)
        var instance_id := StringName(record.get("instance_id", &""))
        var item := _definition(unit, record)
        if (
            not slot
            or not item
            or not slot.can_equip(item)
            or item.weight < 0
            or item.stack_size != 1
            or instance_id.is_empty()
            or slots.has(slot_id)
            or instances.has(instance_id)
        ):
            errors.append("Invalid, duplicate or missing equipped item in slot %s." % slot_id)
            continue
        slots[slot_id] = true
        instances[instance_id] = true
        prepared.append({"slot": slot, "template": item, "instance_id": instance_id})
    if not errors.is_empty():
        return errors
    for child in unit.get_children():
        if child is UnitEquipmentSlot:
            child.clear_equipment()
    for entry in prepared:
        var item := Equipable.create(entry.template, entry.instance_id)
        item.restoring_loadout = true
        entry.slot.template_id = entry.template.id
        entry.slot.add_child(item)
    return errors


## Returns the unit’s equipment slot for the supplied slot ID, or no slot when unavailable.
static func _slot(unit: BattleUnit, slot_id: int) -> UnitEquipmentSlot:
    for child in unit.get_children():
        if child is UnitEquipmentSlot and child.slot == slot_id:
            return child
    return null


## Finds the equipment definition recorded in a saved entry, using registered definitions and its
## saved resource path.
static func _definition(unit: BattleUnit, record: Dictionary) -> EquipmentTemplate:
    var id := StringName(record.get("template_id", &""))
    var definitions: Dictionary = BattleRepository.kinds.get(BattleRepository.BATTLE_EQUIPMENT, {})
    var item: EquipmentTemplate = definitions.get(id) as EquipmentTemplate
    if not item and unit.template_resource.equipment:
        for candidate in unit.template_resource.equipment.all:
            if candidate and candidate.id == id:
                item = candidate
    var path: String = record.get("resource_path", "")
    if not item and path.begins_with("res://") and ResourceLoader.exists(path):
        item = load(path) as EquipmentTemplate
    return item if item and item.id == id else null
