extends Node
## Holds one active quest's definition, ordered steps and current progress.
class_name QuestOperator

## Quest definition supplying the ID and ordered steps for this runtime quest.
var template: GameQuest
## Lookup ID used to find this entry in the relevant resource collection.
var id: StringName
## List of all steps used by this script.
var all_steps: Array[GameQuestStep]
## Quest step currently selected by this runtime quest.
var current_step: GameQuestStep
## List of completed steps used by this script.
var completed_steps: Array[GameQuestStep]
## Order number of the current quest step.
var step:
    get:
        return current_step.order


## Copies the quest definition’s steps, sorts them by order number and selects the first step.
## Requires the definition to contain a step.
func init(quest: GameQuest) -> void:
    template = quest
    id = template.id
    name = template.id
    for new_step in template.steps:
        all_steps.append(new_step)
    all_steps.sort_custom(sort_steps)
    advance_step()


## Moves the previous current step to completed_steps and selects the next remaining step. Requires
## at least one step to remain.
func advance_step() -> void:
    if current_step != null:
        completed_steps.append(all_steps.pop_front())

    current_step = all_steps[0]


## Repeatedly advances until the current step reaches the requested order number. It does not move
## backwards and requires enough remaining steps.
func advance_to(new_step: int) -> void:
    while step < new_step:
        advance_step()


## Returns true when the first quest step has a lower order number, so steps sort from earliest to
## latest.
func sort_steps(first_item, second_item) -> bool:
    if first_item.order < second_item.order:
        return true
    return false
