extends VNRequirement
## Checks whether a required quest is present at the requested step.
class_name VNRequirementQuest

## Quest whose current step is checked by this requirement.
@export var quest_required: GameQuest
## Lowest quest step that satisfies this requirement; later steps also pass.
@export var required_step: int


## Returns true when the required quest is present and its current step is at least the configured
## step.
func has_requirement() -> bool:
    var has_quest: bool = SystemAdministrators.has_quest(quest_required.id)
    var quest_step: int = SystemAdministrators.get_quest_step(quest_required.id)

    if has_quest and quest_step >= required_step:
        return true
    return false
