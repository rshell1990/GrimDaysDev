extends Node
#region EQUIPABLE
## An equipable item's node.
class_name Equipable
#endregion

#region VARIABLES
##  The resource that contains the information to create the equipable item.
var template: EquipmentTemplate
## The slot(s) a equipable item can occupy.
var equips_to: Array[UnitEquipmentSlot.SLOT]
## Runtime owner of this equipable.
var attached_unit: BattleUnit
## Persisted identity of this item instance; never derived from the combat actor.
var item_instance_id: StringName
## Load reconstructs ongoing grants but must not replay instant OnEquip behavior.
var restoring_loadout: bool = false
## All grants from this item share a removable, save-stable ownership key.
var grant_source_id: StringName:
    get:
        return StringName("equipment:%s" % item_instance_id)
#endregion


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    attached_unit = get_parent().get_parent() as BattleUnit
    if not attached_unit or not template:
        push_error("Equipable must be parented to a BattleUnit equipment slot before it becomes ready.")
        return
    var weight_stat := attached_unit.get_stat(CombatStats.STATS.Weight)
    if weight_stat and template.weight != 0:
        weight_stat.add_modifier(
            UnitStatModifier.create(
                StringName("%s:weight" % grant_source_id),
                grant_source_id,
                CombatStats.STATS.Weight,
                UnitStatModifier.OPERATION.FLAT_ADD,
                template.weight
            )
        )
    for stat_id: CombatStats.STATS in template.stat_bonuses:
        var stat := attached_unit.get_stat(stat_id)
        if not stat:
            push_error("Equipment %s grants a stat not present on %s." % [template.id, attached_unit.name])
            continue
        stat.add_modifier(
            UnitStatModifier.create(
                StringName("%s:stat:%s" % [grant_source_id, stat_id]),
                grant_source_id,
                stat_id,
                UnitStatModifier.OPERATION.FLAT_ADD,
                template.stat_bonuses[stat_id]
            )
        )
    for effect in template.get_all_effects():
        if (
            restoring_loadout
            and effect.trigger == CombatEffects.TRIGGER.EQUIP
            and effect.lifetime == EffectTemplate.LIFETIME.INSTANT
        ):
            continue
        # The wearer scales/owns attacks; the item owns the grants for removal.
        var granted := attached_unit.add_effect(
            attached_unit, attached_unit, effect, {"source_id": grant_source_id, "defer_application": true}
        )
        if (
            granted
            and effect.trigger == CombatEffects.TRIGGER.EQUIP
            and effect.lifetime == EffectTemplate.LIFETIME.INSTANT
        ):
            granted.applied.connect(granted.complete_trigger_cycle, CONNECT_ONE_SHOT)
            granted.apply()
    if template is EquipmentWeaponTemplate and template.basic_action_template:
        attached_unit.add_basic_action_override(self, template.basic_action_template)


## Releases owned state and signal-driven effects before this node leaves the scene tree.
func _exit_tree() -> void:
    if not attached_unit:
        return
    if attached_unit.effect_manager:
        attached_unit.effect_manager.remove_effects_from_source(grant_source_id)
    for stat: UnitGenericStat in attached_unit.stat_dictionary.values():
        stat.remove_modifiers_from_source(grant_source_id)
    attached_unit.remove_basic_action_override(self)


#region CONSTRUCTOR
## Creates a new equipable item node that can be added to the scene tree.
static func create(equipment: EquipmentTemplate, instance_id: StringName = &"") -> Equipable:
    if not equipment:
        return null

    var new_equipment := Equipable.new()
    new_equipment.name = equipment.id
    new_equipment.template = equipment
    new_equipment.item_instance_id = (
        instance_id if not instance_id.is_empty() else StringName(Crypto.new().generate_random_bytes(16).hex_encode())
    )
    new_equipment.equips_to.assign(equipment.equips_to)
    return new_equipment
#endregion
