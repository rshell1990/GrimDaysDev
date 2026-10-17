extends Resource
## One authored quest step, including its order, hint and requirements.
class_name GameQuestStep

## Position of this step in its quest's ordered sequence.
@export var order: int
## Hint text associated with this step.
@export_multiline var hint: String
## List of requirements used by this script.
@export var requirements: Array[VNRequirement]
