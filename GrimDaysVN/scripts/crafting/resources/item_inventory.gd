extends RefCounted
class_name VNItemInventory

const MAX_ITEM_COUNT: int = 2147483647

var counts: Dictionary[StringName, int] = {}

func add_item(item: VNItemTemplate, amount: int = 1) -> bool:
    if not item or not item.id is StringName or item.id.is_empty() or amount < 1:
        return false
    var current: int = counts.get(item.id, 0)
    if amount > MAX_ITEM_COUNT - current:
        return false
    counts[item.id] = current + amount
    return true

func remove_item(item_id: StringName, amount: int = 1) -> bool:
    if item_id.is_empty() or amount < 1 or counts.get(item_id, 0) < amount:
        return false
    var remaining: int = counts[item_id] - amount
    if remaining == 0:
        counts.erase(item_id)
    else:
        counts[item_id] = remaining
    return true

func get_count(item_id: StringName) -> int:
    return counts.get(item_id, 0)

func capture_state() -> Dictionary:
    return {"items": counts.duplicate()}

func restore_state(data: Dictionary, catalog: VNItemTemplates) -> PackedStringArray:
    var errors := PackedStringArray()
    var saved_items: Variant = data.get("items", {})
    if not saved_items is Dictionary:
        return PackedStringArray(["Invalid item inventory data."])

    var restored: Dictionary[StringName, int] = {}
    for raw_id: Variant in saved_items:
        var item_id := StringName(str(raw_id))
        var amount: Variant = saved_items[raw_id]
        if (
            item_id.is_empty()
            or not catalog
            or not catalog.get_item(item_id)
            or not (amount is int or amount is float)
            or not is_finite(float(amount))
            or float(amount) != floor(float(amount))
            or amount < 1
            or amount > MAX_ITEM_COUNT
        ):
            errors.append("Invalid item inventory entry: %s." % raw_id)
            continue
        restored[item_id] = int(amount)

    if errors.is_empty():
        counts = restored
    return errors
