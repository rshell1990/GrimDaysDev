extends Resource
#region RESOURCE TEMPLATE
# The base class for all resources in this project should inherit from. Providing a
# clean way to seperate them from the generic resource class that the engine uses.
# Also will require all resources to be provided with a StringName id.
## Coordinates resource template behavior for the battle system.
class_name ResourceTemplate
#endregion

#region BASE
@export_category("Base")
## The identifier to reference this template by.
@export var id: StringName
#endregion
