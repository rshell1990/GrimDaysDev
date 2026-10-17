extends Node
#region EQUIPMENT SLOT
## A node that holds an equipable item node.
class_name UnitEquipmentSlot
#endregion

#region PROPERTIES
## What equipable is currently in the slot.
var equipped:
    get():
        if get_child_count() < 1:
            return null
        return get_child(0)
    set(equipable):
        if not equipable:
            return

        add_child(equipable)

#endregion

## Configures the slot used by this unit equipment slot.
@export var slot: SLOT = SLOT.LeftHand

## Stable template id used to correlate or persist this unit equipment slot.
var template_id: StringName
## Runtime owner of this unit equipment slot.
var attached_unit: BattleUnit


## Initializes tree-dependent state as this node enters the scene tree.
func _enter_tree() -> void:
    var parent = get_parent()
    assert(parent is BattleUnit)
    attached_unit = parent
    parent.set_meta(TYPES[slot], self)


#region MAIN
## Determines if an equipable is able to be equipped into the slot.
func can_equip(equipable_template: EquipmentTemplate) -> bool:
    return equipable_template != null and slot in equipable_template.equips_to


## Equips an item into this slot, first completing removal of the prior item.
func equip(target: Variant, equipable_template: EquipmentTemplate, instance_id: StringName = &"") -> Equipable:
    if target != attached_unit or not can_equip(equipable_template):
        return null
    if equipped:
        await unequip()
    template_id = equipable_template.id
    return spawn_equipment(equipable_template, instance_id)


## Handles equipment for this unit equipment slot.
func spawn_equipment(
    equipable_template: EquipmentTemplate, instance_id: StringName = &"", restoring: bool = false
) -> Equipable:
    var equipable := Equipable.create(equipable_template, instance_id)
    equipable.restoring_loadout = restoring
    equipped = equipable
    return equipable


## Removes the current item and waits until its effects have been cleaned up.
func unequip() -> void:
    clear_equipment()
    await get_tree().process_frame


## Synchronous grant revocation used by load reconstruction. Deferred deletion
## happens only after removing the node, so old grants cannot overlap new ones.
func clear_equipment() -> void:
    var old_equipable: Equipable = equipped
    template_id = &""
    if old_equipable:
        remove_child(old_equipable)
        old_equipable.queue_free()


#endregion


#region SAVE / LOAD
## When the game is loaded, re-equip the stored equipable by it's saved id.
func on_load(data: Dictionary) -> void:
    var saved_id := StringName(data.get("equipped", &""))
    if saved_id.is_empty():
        await unequip()
        return
    var definitions: Dictionary = BattleRepository.kinds.get(BattleRepository.BATTLE_EQUIPMENT, {})
    var definition := definitions.get(saved_id) as EquipmentTemplate
    if not can_equip(definition):
        CustomLogger.warn(self, on_load, "Cannot restore equipment %s." % saved_id, CustomLogger.LEVEL.IMPORTANT)
        return
    await unequip()
    template_id = definition.id
    spawn_equipment(definition, StringName(data.get("instance_id", &"")), true)


## When the game is saved, save the current equipable's id if something is in the slot, otherwise save an empty string.
func _get_state() -> Dictionary:
    var state = {
        "equipped": equipped.template.id if equipped != null else "",
        "instance_id": equipped.item_instance_id if equipped != null else "",
    }
    return state


#endregion

#region CONSTANTS
## The type of slots for equipment.
enum SLOT { LeftHand = 0, LeftRing = 1, RightHand = 2, RightRing = 3, Chest = 4, Neck = 5, Hands = 6 }
## Fixed types value shared by all unit equipment slot instances.
const TYPES: Dictionary[SLOT, StringName] = {
    SLOT.LeftHand: &"Left_Hand",
    SLOT.RightHand: &"Right_Hand",
    SLOT.Hands: &"Hands",
    SLOT.Neck: &"Neck",
    SLOT.Chest: &"Chest",
    SLOT.LeftRing: &"Left_Ring",
    SLOT.RightRing: &"Right_Ring"
}

#endregion
