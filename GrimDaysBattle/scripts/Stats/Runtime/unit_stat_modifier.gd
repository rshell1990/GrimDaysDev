extends RefCounted
## Coordinates unit stat modifier behavior for the battle system.
class_name UnitStatModifier

## A reversible contribution to one runtime stat.
##
## Modifiers are grouped by [member source_id] so an equipment item, skill-tree
## unlock, or active effect can remove only the values that it granted.

## Enumerates the supported operation values.
enum OPERATION {
    FLAT_ADD,
    PERCENT_ADD,
    MULTIPLY,
    OVERRIDE,
    CAPPED_ADD,
}

## Enumerates the supported lifetime values.
enum LIFETIME {
    ## The modifier remains until its source (equipment/effect) is removed.
    WHILE_SOURCE_ACTIVE,
    ## The modifier is part of the unit's persistent progression and is saved.
    PERSISTENT,
}

## Runtime modifier id state used by this unit stat modifier.
var modifier_id: StringName
## Stable source id used to correlate or persist this unit stat modifier.
var source_id: StringName
## Runtime stat state used by this unit stat modifier.
var stat: CombatStats.STATS = CombatStats.STATS.Empty
## Runtime operation state used by this unit stat modifier.
var operation: int = OPERATION.FLAT_ADD
## Runtime amount state used by this unit stat modifier.
var amount: float
## Upper bound of this contribution only; values already above it are preserved.
var contribution_cap: float = INF
## Runtime priority state used by this unit stat modifier.
var priority: int
## Runtime lifetime state used by this unit stat modifier.
var lifetime: int = LIFETIME.WHILE_SOURCE_ACTIVE


## Creates and returns a configured unit stat modifier instance.
static func create(
    new_modifier_id: StringName,
    new_source_id: StringName,
    stat_id: CombatStats.STATS,
    new_operation: int,
    new_amount: float,
    new_lifetime: int = LIFETIME.WHILE_SOURCE_ACTIVE,
    new_priority: int = 0,
) -> UnitStatModifier:
    var modifier := UnitStatModifier.new()
    modifier.modifier_id = new_modifier_id
    modifier.source_id = new_source_id
    modifier.stat = stat_id
    modifier.operation = new_operation
    modifier.amount = new_amount
    modifier.lifetime = new_lifetime
    modifier.priority = new_priority
    return modifier


## Returns whether permanent.
func is_permanent() -> bool:
    return lifetime == LIFETIME.PERSISTENT
