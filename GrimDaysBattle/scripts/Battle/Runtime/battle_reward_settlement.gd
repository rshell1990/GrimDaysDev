extends RefCounted
## Validates victory rewards before mutating persistent party state. The caller
## retains foes until success; receipts remain readable after encounter cleanup.
class_name BattleRewardSettlement


## Every originally deployed member receives the full encounter + defeated-foe
## experience amount. Loot/currency go to the shared stash, never combat backpacks.
## Repeated successful calls are no-ops; failures preserve all inventories/XP.
static func apply(result: BattleResult, party: BattlePartyManager, allies: Array[BattleUnit]) -> PackedStringArray:
    if not result or not result.finalized or not is_instance_valid(party):
        return PackedStringArray(["Reward settlement requires a finalized result and runtime party."])
    if result.reward_settlement_in_progress:
        return PackedStringArray(["Reward settlement is already in progress."])
    if result.rewards_settled:
        return []
    result.reward_capacity_blocked = false
    if not result.is_victory():
        if not result.is_defeat():
            return PackedStringArray(["Only accepted victory/defeat results can settle."])
        result.rewards_settled = true
        result.reward_receipt = {"experience_per_member": 0, "members": [], "items": []}
        return []
    var experience: Variant = result.rewards.get("experience", 0)
    var money: Variant = result.rewards.get("money", 0)
    var configured_items: Variant = result.rewards.get("items", [])
    if (
        not experience is int
        or experience < 0
        or experience > 2147483647
        or not money is int
        or money < 0
        or not configured_items is Array
    ):
        return PackedStringArray(["Rewards require non-negative integer experience/money and an item array."])
    for key in result.rewards:
        if key not in ["experience", "money", "items"]:
            return PackedStringArray(["Unknown reward field: %s." % key])
    var loot: Array = configured_items.duplicate(true)
    if money > 0:
        loot.append(
            {
                "template_id": Inventory.COINS_TEMPLATE.id,
                "resource_path": Inventory.COINS_TEMPLATE.resource_path,
                "count": money
            }
        )
    for snapshot in result.foe_snapshots:
        if snapshot.active:
            continue
        var foe_experience: Variant = snapshot.get("experience_reward", 0)
        if not foe_experience is int or foe_experience < 0 or foe_experience > 2147483647 - experience:
            return PackedStringArray(["Invalid foe experience reward."])
        experience += foe_experience
        loot.append_array(snapshot.get("loot", []))
    result.reward_offer = loot.duplicate(true)
    var member_ids: Array[StringName] = []
    for unit in allies:
        if not is_instance_valid(unit) or not party.owns_unit(unit) or not unit.get_stat(CombatStats.STATS.Experience):
            return PackedStringArray(["A deployed party member cannot receive experience."])
        if unit.template_resource.id in member_ids:
            return PackedStringArray(["Duplicate deployed reward recipient."])
        member_ids.append(unit.template_resource.id)
    var staged := Inventory.new()
    var definitions: Dictionary = {Inventory.COINS_TEMPLATE.id: Inventory.COINS_TEMPLATE}
    for item: ItemBase in party.stash.slots.values():
        if item:
            definitions[item.id] = item.template
    var errors := staged.restore_state(party.stash.capture_state(), definitions)
    var receipt: Array[Dictionary] = []
    var capacity_errors_only: bool = true
    if errors.is_empty():
        for index in loot.size():
            result.reward_capacity_blocked = false
            var error := _stage_item(staged, loot[index], definitions, receipt, result, index)
            if not error.is_empty():
                errors.append(error)
                capacity_errors_only = capacity_errors_only and result.reward_capacity_blocked
    else:
        capacity_errors_only = false
    # Never present raw malformed records merely because another valid item also
    # exceeded capacity. Only fully validated offers are safe for the choice UI.
    result.reward_capacity_blocked = not errors.is_empty() and capacity_errors_only
    if not errors.is_empty():
        staged.free()
        return errors
    # No awaits: publish the guard before any stat observer could re-enter payment.
    result.reward_settlement_in_progress = true
    errors = party.stash.restore_state(staged.capture_state(), definitions)
    staged.free()
    if not errors.is_empty():
        result.reward_settlement_in_progress = false
        return errors
    result.reward_receipt = {"experience_per_member": experience, "members": member_ids, "items": receipt}
    for unit in allies:
        var stat := unit.get_stat(CombatStats.STATS.Experience)
        stat.set_base(stat.Base + experience)
    result.rewards_settled = true
    result.reward_settlement_in_progress = false
    return []


## Uses only copied identity/count data; a freed foe is never queried for loot.
static func _stage_item(
    staged: Inventory,
    record: Variant,
    definitions: Dictionary,
    receipt: Array[Dictionary],
    result: BattleResult,
    index: int
) -> String:
    if not record is Dictionary:
        return "Invalid reward item record."
    var id: Variant = record.get("template_id")
    var path: Variant = record.get("resource_path", "")
    var count: Variant = record.get("count")
    var instance_id: Variant = record.get("instance_id", &"")
    if (
        not (id is String or id is StringName)
        or not path is String
        or not count is int
        or count < 1
        or not (instance_id is String or instance_id is StringName)
    ):
        return "Invalid reward item identity or quantity."
    var definition := Inventory.resolve_definition(StringName(id), path, definitions)
    if not definition:
        return "Unknown reward item: %s." % id
    definitions[definition.id] = definition
    var declined: int = result.discarded_rewards.get(index, 0)
    if declined < 0 or declined > count:
        return "Invalid declined reward quantity."
    count -= declined
    if count == 0:
        return ""
    var item := ItemBase.create(definition, count, StringName(instance_id))
    if definition is EquipmentTemplate and (definition.stack_size != 1 or staged._has_instance(item.instance_id)):
        return "Invalid or duplicate reward equipment identity: %s." % id
    if definition is EquipmentTemplate and count > 1 and not item.instance_id.is_empty():
        return "Multiple equipment copies cannot share one reward identity."
    var fits: bool = (
        staged.money <= Inventory.COINS_TEMPLATE.stack_size - count
        if item.id == Inventory.COINS_TEMPLATE.id
        else staged._available_capacity(item) >= count
    )
    if not fits:
        result.reward_capacity_blocked = true
        return "Make room in the shared stash or leave behind: %s ×%s." % [definition.display_name, count]
    var previous_instances: Dictionary = {}
    if definition is EquipmentTemplate:
        for stored: ItemBase in staged.slots.values():
            if stored:
                previous_instances[stored.instance_id] = true
    if not staged.add_item(item):
        return "Could not stage reward item: %s." % id
    if definition is EquipmentTemplate:
        for stored: ItemBase in staged.slots.values():
            if stored and stored.id == definition.id and not previous_instances.has(stored.instance_id):
                receipt.append(
                    {
                        "template_id": definition.id,
                        "resource_path": definition.resource_path,
                        "count": 1,
                        "instance_id": stored.instance_id,
                        "display_name": definition.display_name
                    }
                )
        return ""
    receipt.append(
        {
            "template_id": definition.id,
            "resource_path": definition.resource_path,
            "count": count,
            "instance_id": StringName(instance_id),
            "display_name": definition.display_name
        }
    )
    return ""
