extends VNRequirement
## Checks that story progress has reached the required world-stage number.
class_name VNRequirementWorldMinimum

## Story-progress number used by events and requirements to decide what is available.
@export var world_stage: int


## Returns whether story progress has reached or passed the configured world-stage number.
func has_requirement() -> bool:
    if GameManager.world_stage >= world_stage:
        return true
    return false
