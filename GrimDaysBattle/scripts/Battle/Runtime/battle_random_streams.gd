extends RefCounted
## Assigns reproducible, independent random streams to battle participants.
class_name BattleRandomStreams

## Prime offset keeps adjacent participants from sharing the same stream.
const UNIT_SEED_STEP: int = 104729


## Seeds units in stable team/input order for production and debug battles.
static func seed_participants(
    allies: Array[BattleUnit],
    foes: Array[BattleUnit],
    battle_seed: int,
) -> void:
    var index: int
    for unit in allies + foes:
        if is_instance_valid(unit) and unit.randomizer:
            unit.randomizer.set_seed(battle_seed + index * UNIT_SEED_STEP)
        index += 1
