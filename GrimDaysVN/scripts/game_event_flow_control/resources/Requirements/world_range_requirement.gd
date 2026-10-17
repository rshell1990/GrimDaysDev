extends VNRequirement
## Checks that story progress falls within an inclusive range of world-stage numbers.
class_name VNRequirementWorldRange

## Lowest allowed world-stage number, included in the accepted range.
@export var minimum: int
## Highest allowed world-stage number, included in the accepted range.
@export var maximum: int


## Returns whether the current world-stage number is between the minimum and maximum, including both
## endpoints.
func has_requirement() -> bool:
    if GameManager.world_stage > maximum:
        return false
    if GameManager.world_stage < minimum:
        return false

    return true
