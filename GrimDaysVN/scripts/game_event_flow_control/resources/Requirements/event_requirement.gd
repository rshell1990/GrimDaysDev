extends VNRequirement
## Checks whether the game has already encountered a particular story event.
class_name VNRequirementGameEvent

## ID of the story event that must already have been seen.
@export var event: StringName


## Returns whether the required event ID appears in the game manager's list of seen events.
func has_requirement() -> bool:
    if event in GameManager.seen_events:
        return true

    return false
