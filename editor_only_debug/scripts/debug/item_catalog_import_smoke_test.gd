extends SceneTree

const VN_ITEMS = preload("res://GrimDaysVN/resources/items/imported/all_items.tres")
const VN_REPOSITORY_SCRIPT = preload("res://GrimDaysVN/scripts/repositories/item_repository.gd")
const VN_INVENTORY_SCRIPT = preload("res://GrimDaysVN/scripts/crafting/resources/item_inventory.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var errors := PackedStringArray()
    _check_catalogs(errors)
    _check_vn_repository(errors)
    _check_vn_inventory(errors)
    _check_battle_resources(errors)
    if errors.is_empty():
        print("PASS: imported all 254 catalog items into both projects.")
        quit(0)
        return
    for error in errors:
        push_error(error)
    quit(1)

func _check_catalogs(errors: PackedStringArray) -> void:
    var vn_items: Array = VN_ITEMS.get("all")
    if vn_items.size() != 254:
        errors.append("VN catalog expected 254 items; found %s." % vn_items.size())
    var vn_ids: Dictionary = {}
    for item: Resource in vn_items:
        var item_id: Variant = item.get("id") if item else null
        if not item_id is StringName or item_id.is_empty() or vn_ids.has(item_id):
            errors.append("VN catalog contains an empty item or duplicate item ID.")
            continue
        vn_ids[item_id] = true

func _check_vn_repository(errors: PackedStringArray) -> void:
    var repository: Node = VN_REPOSITORY_SCRIPT.new()
    repository.set("resource", VN_ITEMS)
    root.add_child(repository)
    var master: Dictionary = repository.get("master")
    var vn_items: Array = VN_ITEMS.get("all")
    if master.size() != vn_items.size():
        errors.append("VN item repository did not index every item.")
    for item: Resource in vn_items:
        var item_id: Variant = item.get("id")
        if master.get(item_id) != item:
            errors.append("VN item repository did not resolve %s." % item_id)
            break
    repository.free()

func _check_vn_inventory(errors: PackedStringArray) -> void:
    var inventory: RefCounted = VN_INVENTORY_SCRIPT.new()
    var potion: Resource = VN_ITEMS.call("get_item", &"potion_heal_minor")
    var potion_id: StringName = potion.get("id")
    if not inventory.call("add_item", potion, 3) or inventory.call("get_count", potion_id) != 3:
        errors.append("VN inventory failed to add an imported item.")
        return
    var snapshot: Dictionary = inventory.call("capture_state")
    var json_snapshot: Dictionary = JSON.parse_string(JSON.stringify(snapshot))
    var restored: RefCounted = VN_INVENTORY_SCRIPT.new()
    if not (restored.call("restore_state", json_snapshot, VN_ITEMS) as PackedStringArray).is_empty():
        errors.append("VN inventory failed to restore a valid JSON snapshot.")
        return
    if restored.call("get_count", potion_id) != 3 or not restored.call("remove_item", potion_id, 2):
        errors.append("VN inventory failed to remove an imported item.")
    var before: Dictionary = restored.call("capture_state")
    var invalid: Dictionary = {"items": {str(potion_id): 1.5}}
    if (restored.call("restore_state", invalid, VN_ITEMS) as PackedStringArray).is_empty() or restored.call("capture_state") != before:
        errors.append("VN inventory accepted an invalid snapshot or changed state on failure.")

func _check_battle_resources(errors: PackedStringArray) -> void:
    var directory := DirAccess.open("res://GrimDaysBattle/resources/items/catalog")
    if not directory:
        errors.append("Battle item resources directory is missing.")
        return
    var file_count := directory.get_files().size() - 1
    if file_count != 254:
        errors.append("Battle catalog expected 254 item resources; found %s." % file_count)
    var collection: String = FileAccess.get_file_as_string(
        "res://GrimDaysBattle/resources/items/catalog/all_items.tres"
    )
    if collection.count("[ext_resource type=\"Resource\"") != 254:
        errors.append("Battle item collection does not reference all 254 resources.")
    var registry: String = FileAccess.get_file_as_string("res://GrimDaysBattle/resources/items/_equipment.tres")
    if registry.count("[ext_resource type=\"Resource\"") != 256:
        errors.append("BattleEquipment does not register all imported items and existing equipment.")
