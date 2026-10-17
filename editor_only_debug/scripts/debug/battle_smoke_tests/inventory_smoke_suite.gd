extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"


## Runs the inventory smoke checks. Creates or uses test objects and stops on failed assertions.
func run() -> void:
    var inventory := Inventory.new()
    inventory.size = 3
    add_child(inventory)
    assert(inventory.money == 0)

    var coins := ItemBase.create(Inventory.COINS_TEMPLATE, 9)
    assert(inventory.add_item(coins))
    assert(inventory.money == 9, "Currency pickups must update only reserved slot zero.")
    assert(inventory.slots[1] == null, "Currency must not consume an ordinary item slot.")

    var potion_template := ItemTemplate.new()
    potion_template.id = &"inventory_test_potion"
    potion_template.stack_size = 2
    assert(inventory.add_item(ItemBase.create(potion_template, 5)))
    assert(inventory.slots[1].count == 2)
    assert(inventory.slots[2].count == 2)
    assert(inventory.slots[3].count == 1)
    var snapshot: Array[int] = [
        inventory.slots[1].count,
        inventory.slots[2].count,
        inventory.slots[3].count,
    ]
    assert(not inventory.add_item(ItemBase.create(potion_template, 2)))
    assert(
        snapshot == [inventory.slots[1].count, inventory.slots[2].count, inventory.slots[3].count],
        "A pickup that cannot fully fit must leave existing stacks unchanged.",
    )
    assert(inventory.use_item(2, 2))
    assert(inventory.slots[1].count == 2 and inventory.slots[2].count == 1)
    assert(inventory.slots[3] == null, "Consuming a stack must compact remaining items.")
    assert(not inventory.use_item(99, 1), "Invalid slots must fail without indexing the dictionary.")
    await _test_transfer_and_restore(inventory, potion_template)
    await free_node(inventory)
    await _test_party_ownership()
    await _test_equipment_exchange()


## Transfers conserve quantities, failed loads are atomic, and re-entry retains items.
func _test_transfer_and_restore(source: Inventory, potion: ItemTemplate) -> void:
    var destination := Inventory.new()
    add_child(destination)
    assert(source.transfer_to(destination, 1, 1))
    assert(source.slots[1].count == 1 and destination.slots[1].count == 1)
    assert(source.slots[1] != destination.slots[1])
    assert(not source.transfer_to(destination, 1, 3))
    assert(not source.transfer_to(source, 1, 1))
    assert(source.transfer_to(destination, 1, 1))
    assert(not source.transfer_to(destination, 1, 1), "Full destination cannot consume source.")
    assert(source.slots[1].count == 1)
    assert(source.transfer_to(destination, 0, 4))
    assert(source.money == 5 and destination.money == 4)
    var saved: Dictionary = destination.capture_state()
    remove_child(destination)
    add_child(destination)
    assert(destination.capture_state() == saved, "Re-entering the tree must not clear inventory.")
    assert(destination.use_item(1, 1))
    assert(destination.restore_state(saved, {potion.id: potion}).is_empty())
    assert(destination.capture_state() == saved)
    var json_saved: Dictionary = JSON.parse_string(JSON.stringify(saved))
    assert(destination.restore_state(json_saved, {potion.id: potion}).is_empty())
    assert(destination.capture_state() == saved, "JSON preserves capacity, money, slots and counts.")
    for field in ["size", "money", "slot", "count"]:
        for bad_value in [true, 1.5, NAN, INF, "1"]:
            var malformed := saved.duplicate(true)
            if field in ["size", "money"]:
                malformed[field] = bad_value
            else:
                malformed.items[0][field] = bad_value
            assert(not destination.restore_state(malformed, {potion.id: potion}).is_empty())
            assert(destination.capture_state() == saved, "Invalid numeric fields must reject atomically.")
    var duplicate_slot := json_saved.duplicate(true)
    duplicate_slot.items.append(duplicate_slot.items[0].duplicate())
    duplicate_slot.items[1].slot = int(duplicate_slot.items[0].slot)
    assert(not destination.restore_state(duplicate_slot, {potion.id: potion}).is_empty())
    assert(destination.capture_state() == saved)
    var invalid: Dictionary = saved.duplicate(true)
    invalid.items.append(invalid.items[0].duplicate())
    assert(not destination.restore_state(invalid, {potion.id: potion}).is_empty())
    assert(destination.capture_state() == saved)
    invalid = saved.duplicate(true)
    invalid.items[0].count = 99
    assert(not destination.restore_state(invalid, {potion.id: potion}).is_empty())
    assert(destination.capture_state() == saved)
    assert(not destination.restore_state(saved).is_empty(), "Unknown authored IDs must not be silently dropped.")
    assert(destination.capture_state() == saved)
    await free_node(destination)


## Full party reconstruction preserves separate ownership. Storage and transfers do
## not grant equipment weight, and an encounter freezes preparation transfers.
func _test_party_ownership() -> void:
    var manager: BattlePartyManager = BattleController.party_manager
    var original: Dictionary = manager._get_state()
    var unit: BattleUnit = manager.runtime_units[CELINE_TEMPLATE.id]
    var potion := ItemTemplate.new()
    potion.id = &"inventory_persistent_potion"
    potion.stack_size = 5
    var gear := EquipmentTemplate.new()
    gear.id = &"inventory_carried_gear"
    gear.weight = 500
    BattleRepository.kinds[&"InventorySmokeItems"] = {potion.id: potion, gear.id: gear}
    var weight: float = unit.get_stat(CombatStats.STATS.Weight).Current
    var speed: float = unit.speed
    assert(unit.inventory and unit.inventory != manager.stash)
    assert(manager.stash.add_item(ItemBase.create(potion, 3)))
    assert(manager.stash.add_item(ItemBase.create(gear)))
    assert(manager.stash.add_item(ItemBase.create(Inventory.COINS_TEMPLATE, 12)))
    assert(manager.transfer_item(&"", unit.template_resource.id, 1, 2))
    assert(manager.transfer_item(&"", unit.template_resource.id, 2))
    assert(unit.inventory.slots[1].count == 2 and manager.stash.slots[1].count == 1)
    assert(unit.get_stat(CombatStats.STATS.Weight).Current == weight and unit.speed == speed)
    assert(not manager.transfer_item(&"unknown", &"", 1))
    assert(manager.acquire_encounter(self))
    assert(not manager.transfer_item(&"", unit.template_resource.id, 1))
    manager.release_encounter(self)
    var snapshot: Dictionary = manager._get_state()
    manager.restore(snapshot)
    unit = manager.runtime_units[CELINE_TEMPLATE.id]
    assert(unit.inventory.capture_state() == snapshot.units[CELINE_TEMPLATE.id].inventory)
    assert(manager.stash.capture_state() == snapshot.stash)
    assert(unit.get_stat(CombatStats.STATS.Weight).Current == weight and unit.speed == speed)
    assert(manager.transfer_item(unit.template_resource.id, &"", 1, 2))
    assert(manager.stash.slots[1].count == 3)
    manager.restore(original)
    BattleRepository.kinds.erase(&"InventorySmokeItems")
    await get_tree().process_frame


## Full backpacks allow replacement, not silent deletion on unequip. Equipment
## identities and weight follow the item across stash, storage and occupied slots.
func _test_equipment_exchange() -> void:
    var unit := BattleUnit.create(CELINE_TEMPLATE)
    add_child(unit)
    var party := BattlePartyManager.new()
    party.runtime_units[CELINE_TEMPLATE.id] = unit
    var heavy := EquipmentTemplate.new()
    heavy.id = &"exchange_heavy"
    heavy.weight = 4
    heavy.equips_to.assign([UnitEquipmentSlot.SLOT.LeftHand])
    var light := EquipmentTemplate.new()
    light.id = &"exchange_light"
    light.weight = 2
    light.equips_to.assign([UnitEquipmentSlot.SLOT.LeftHand])
    var filler := ItemTemplate.new()
    filler.id = &"exchange_filler"
    var weight := unit.get_stat(CombatStats.STATS.Weight)
    var baseline: float = weight.Current
    var unit_id: StringName = CELINE_TEMPLATE.id
    var hand: int = UnitEquipmentSlot.SLOT.LeftHand
    assert(party.stash.add_item(ItemBase.create(heavy)))
    var heavy_id: StringName = party.stash.slots[1].instance_id
    assert(not heavy_id.is_empty())
    assert(party.transfer_item(&"", unit_id, 1))
    assert(unit.inventory.slots[1].instance_id == heavy_id and weight.Current == baseline)
    assert(not party.equip_inventory_item(unit_id, 1, UnitEquipmentSlot.SLOT.Chest))
    assert(not party.equip_inventory_item(&"missing", 1, hand))
    assert(party.acquire_encounter(self))
    assert(not party.equip_inventory_item(unit_id, 1, hand))
    party.release_encounter(self)
    assert(party.equip_inventory_item(unit_id, 1, hand))
    assert(unit.get_equipment_slot(hand).equipped.item_instance_id == heavy_id)
    assert(weight.Current == baseline + 4 and unit.inventory.slots[1] == null)
    assert(unit.inventory.add_item(ItemBase.create(light)))
    var light_id: StringName = unit.inventory.slots[1].instance_id
    assert(unit.inventory.add_item(ItemBase.create(filler, unit.inventory.size - 1)))
    assert(not party.unequip_inventory_item(unit_id, hand), "Full storage must leave gear and grants intact.")
    assert(weight.Current == baseline + 4)
    assert(party.equip_inventory_item(unit_id, 1, hand), "A full inventory must still allow a one-for-one swap.")
    assert(unit.inventory.slots[1].instance_id == heavy_id)
    assert(unit.get_equipment_slot(hand).equipped.item_instance_id == light_id)
    assert(weight.Current == baseline + 2)
    assert(unit.inventory.use_item(2, 1))
    assert(party.acquire_encounter(self))
    assert(not party.unequip_inventory_item(unit_id, hand))
    party.release_encounter(self)
    assert(party.unequip_inventory_item(unit_id, hand))
    assert(weight.Current == baseline and unit.get_equipment_slot(hand).equipped == null)
    assert(unit.inventory.slots[unit.inventory.size].instance_id == light_id)
    var saved: Dictionary = unit.inventory.capture_state()
    assert(
        (
            unit
            . inventory
            . restore_state(
                JSON.parse_string(JSON.stringify(saved)), {heavy.id: heavy, light.id: light, filler.id: filler}
            )
            . is_empty()
        )
    )
    assert(unit.inventory.capture_state() == saved)
    assert(party.transfer_item(unit_id, &"", 1))
    assert(party.stash.slots[1].instance_id == heavy_id)
    assert(party.transfer_item(&"", unit_id, 1))
    assert(unit.inventory.slots[unit.inventory.size].instance_id == heavy_id)
    assert(party.equip_inventory_item(unit_id, unit.inventory.size, hand))
    assert(weight.Current == baseline + 4)
    assert(unit.get_equipment_slot(hand).equipped.item_instance_id == heavy_id)
    await free_node(unit)
    party.free()
