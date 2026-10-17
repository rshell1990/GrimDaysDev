extends Object
## Coordinates combat damage behavior for the battle system.
class_name CombatDamage

## Fixed physical damage min modifier value shared by all combat damage instances.
const PHYSICAL_DAMAGE_MIN_MODIFIER: float = 0.85
## Fixed physical damage max modifier value shared by all combat damage instances.
const PHYSICAL_DAMAGE_MAX_MODIFIER: float = 1.15
## Fixed magical damage min modifier value shared by all combat damage instances.
const MAGICAL_DAMAGE_MIN_MODIFIER: float = 0.7
## Fixed magical damage max modifier value shared by all combat damage instances.
const MAGICAL_DAMAGE_MAX_MODIFIER: float = 1.3
## Fixed critical attack damage multiplier value shared by all combat damage instances.
const CRITICAL_ATTACK_DAMAGE_MULTIPLIER: float = 2.0

## Enumerates the supported type values.
enum TYPE { None = 0, Physical = 100, Magic = 200, True = 300 }
