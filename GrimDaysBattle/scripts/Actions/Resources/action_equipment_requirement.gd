extends Resource
## All requirements on an action must pass. Weapons are checked in the two hand slots.
class_name ActionEquipmentRequirement

enum MODE { UNARMED, ANY_WEAPON, WEAPON_TAG }

@export var mode: MODE = MODE.UNARMED
## For example, bladed. Only used by WEAPON_TAG; authors tag the weapon definition.
@export var weapon_tag: StringName = &"bladed"


func get_unavailable_reason(unit: BattleUnit) -> String:
    var weapons: Array[EquipmentWeaponTemplate] = []
    for child in unit.get_children():
        if (
            child is UnitEquipmentSlot
            and child.slot in [UnitEquipmentSlot.SLOT.LeftHand, UnitEquipmentSlot.SLOT.RightHand]
        ):
            var item: Equipable = child.equipped
            if item and item.template is EquipmentWeaponTemplate:
                weapons.append(item.template)
    match mode:
        MODE.UNARMED:
            return "Requires unarmed combat." if not weapons.is_empty() else ""
        MODE.ANY_WEAPON:
            return "Requires an equipped weapon." if weapons.is_empty() else ""
        MODE.WEAPON_TAG:
            for weapon in weapons:
                if not weapon_tag.is_empty() and weapon_tag in weapon.weapon_tags:
                    return ""
            return "Requires a %s weapon." % weapon_tag
    return "Invalid equipment requirement."
