extends RefCounted

## Pure damage rules shared by runtime damage effects. Keeping resolution free
## of scene-tree state makes it deterministic and independently testable.


## Returns the target stat that mitigates this damage type. True and non-damage
## changes deliberately have no mitigation stat.
static func get_resistance_stat(damage_type: int) -> CombatStats.STATS:
    match damage_type:
        CombatDamage.TYPE.Physical:
            return CombatStats.STATS.PhysicalResistance
        CombatDamage.TYPE.Magic:
            return CombatStats.STATS.MagicResistance
        _:
            return CombatStats.STATS.Empty


## Resolves a positive damage magnitude against a percentage resistance.
## Resistance is clamped so malformed data cannot heal a target or produce
## negative damage. True damage bypasses resistance entirely.
static func resolve_damage(
    raw_damage: float,
    damage_type: int,
    resistance_percent: float = 0.0,
) -> float:
    var damage := maxf(raw_damage, 0.0)
    if damage_type == CombatDamage.TYPE.True or damage_type == CombatDamage.TYPE.None:
        return damage
    var mitigation := clampf(resistance_percent, 0.0, 100.0) / 100.0
    return maxf(damage * (1.0 - mitigation), 0.0)


## Samples damage magnitude before critical/resistance. True damage consumes no RNG draw.
static func roll_variance(damage_type: int, rng: RandomNumberGenerator) -> float:
    match damage_type:
        CombatDamage.TYPE.Physical:
            return rng.randf_range(
                CombatDamage.PHYSICAL_DAMAGE_MIN_MODIFIER,
                CombatDamage.PHYSICAL_DAMAGE_MAX_MODIFIER,
            )
        CombatDamage.TYPE.Magic:
            return rng.randf_range(
                CombatDamage.MAGICAL_DAMAGE_MIN_MODIFIER,
                CombatDamage.MAGICAL_DAMAGE_MAX_MODIFIER,
            )
    return 1.0
