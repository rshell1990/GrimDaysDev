#region RANKS
extends ResourceTemplate
##
##
##
## Coordinates ranks template behavior for the battle system.
class_name RanksTemplate
#endregion

const PROGRESSION = preload(
    "res://GrimDaysBattle/scripts/Actions/Resources/action_rank_progression.gd"
)

#region VARIABLES
##
##
## Configures the all used by this ranks template.
@export var all: Array[RankTemplate]
#endregion

@export_group("Generated progression")
## Opt in to one base payload; the explicit list remains unchanged when disabled.
@export var generated: bool = false
@export_range(1, 99, 1) var rank_count: int = 1
@export var base_rank: RankTemplate
## Added to each base cost for every rank after the first. Missing base costs start at zero.
@export var cost_increase_per_rank: Dictionary[CombatStats.STATS, int] = {}


func get_rank_count() -> int:
    return rank_count if generated else all.size()


## Generated results are independent snapshots, never cached against editable resources.
func get_rank(number: int) -> RankTemplate:
    if number < 1 or number > get_rank_count():
        return null
    if not generated:
        return all[number - 1]
    if not validate_progression().is_empty():
        return null
    return PROGRESSION.resolve(base_rank, cost_increase_per_rank, number)


func validate_progression() -> PackedStringArray:
    if not generated:
        return PackedStringArray()
    return PROGRESSION.validate(base_rank, cost_increase_per_rank, rank_count)
