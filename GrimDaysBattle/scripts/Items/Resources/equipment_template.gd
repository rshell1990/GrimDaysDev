extends ItemTemplate
#region EQUIPMENT
## Template for items that are equipped to a unit.
##
class_name EquipmentTemplate
#endregion

## How much this item weighs, creates a penalty for speed.
@export var weight: int
## What slots this equipment can occupy.
@export var equips_to: Array[UnitEquipmentSlot.SLOT]
## Flat combat-stat bonuses granted while this item is equipped.
@export var stat_bonuses: Dictionary[CombatStats.STATS, float] = {}
#region EFFECTS
@export_group("Effects")
## Effects that happen before damage is received by the owner when this item is equipped.
@export var before_hit_effects: Array[EffectTemplate]
## Effects that happen before damage is dealt to a foe by the owner when this item is equipped.
@export var before_hitting_effects: Array[EffectTemplate]
## Effects that happen when damage is received by the owner when this item is equipped.
@export var after_hit_effects: Array[EffectTemplate]
## Effects that happen when damage is dealt by the owner to a foe when this item is equipped.
@export var after_hitting_effects: Array[EffectTemplate]
## Effects that happen when this item is equipped to the owner.
@export var on_equip_effects: Array[EffectTemplate]
## Effects that happen when the owner is defeated while this item is equipped.
@export var on_defeated_effects: Array[EffectTemplate]
## Effects that happen when the owner defeats another while this item is equipped.
@export var on_killing_effects: Array[EffectTemplate]
#endregion


## Returns every effect granted by this item. Trigger routing remains authored on
## each effect template; the arrays only organize equipment data in the inspector.
func get_all_effects() -> Array[EffectTemplate]:
    var effects: Array[EffectTemplate]
    for collection: Array[EffectTemplate] in [
        before_hit_effects,
        before_hitting_effects,
        after_hit_effects,
        after_hitting_effects,
        on_equip_effects,
        on_defeated_effects,
        on_killing_effects,
    ]:
        for effect in collection:
            if effect:
                effects.append(effect)
    return effects
