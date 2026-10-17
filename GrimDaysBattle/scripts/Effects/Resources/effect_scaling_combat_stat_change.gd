extends EffectChangeStatTemplate
## Implements the runtime effect scaling combat stat change template behavior used by the battle effect pipeline.
class_name EffectScalingCombatStatChangeTemplate

## Flag to determine if the scaling should occur from the effect's sender (the unit that applied the effect) or the
## effect's owner (the unit affected by the effect).
@export var scales_from_sender: bool
## Flag to determine if the scaling should occur from the damage multiplier stat.
@export var scales_with_damage: bool = false
## Whether damaging changes may critically strike. Healing never critically strikes.
@export var can_critical: bool = true
## Percentage points added only to this strike's critical roll, not the unit's stat.
@export var critical_chance_bonus: float = 0.0
## Absolute percentage-point bonuses by Action rank; empty uses scalar, short lists hold the last value.
@export var critical_chance_bonus_by_rank: PackedFloat64Array
## Absolute damage multiplier on a critical strike; 2.0 preserves ordinary double damage.
@export_range(0.0, 10.0, 0.05, "or_greater") var critical_damage_multiplier: float = 2.0
## Absolute nonnegative multipliers by Action rank; empty uses scalar, short lists hold the last value.
@export var critical_damage_multiplier_by_rank: PackedFloat64Array
## The combat stat that will affect the amount of this resource change.
@export var scales_with: CombatStats.STATS
## How much the stat contributes to the change. Negative values deal damage;
## positive values restore the target stat.
@export var scales_by: float = 1.0

## Absolute multipliers by Action rank. Empty uses scales_by; short lists hold the final value.
@export var scales_by_by_rank: PackedFloat64Array


## Timed buff/debuff magnitudes belong to runtime instances; an unbound description keeps x symbolic.
func _get_description_value(as_percent: bool) -> Variant:
    if snapshots_amount() and not as_percent:
        return null
    return scales_by * 100.0 if as_percent else scales_by


## Capture at attachment, before the first scheduled tick; REPEAT operations remain live-scaled.
func snapshots_amount() -> bool:
    return (
        duration > 0 and lifetime != LIFETIME.INSTANT and kind in [CombatEffects.KIND.BUFF, CombatEffects.KIND.DEBUFF]
    )
