extends Resource
## Authored quest definition containing its title, ID, description and ordered steps.
class_name GameQuest

## Title shown to the player.
@export var title: String
## Explanatory text shown for this entry.
@export_multiline var description: String
## Lookup ID used to find this entry in the relevant resource collection.
@export var id: StringName
## List of steps used by this script.
@export var steps: Array[GameQuestStep]
