extends Node
#region REPOSITORY
## The generic repository class to store information about resources based on various templates.
class_name ResourceBattleRepository
#endregion

#region EXPORTS
## The resource that stores all the templates.
@export var resource: ResourceTemplates
#endregion

#region VARIABLES
## The dictionary that stores the templates, by id.
var master: Dictionary = {}
#endregion


#region ON INIT
## Runs once when the node enters the scene tree.
func _ready() -> void:
    if not resource:
        return
    populate_master()


## Fill the master dictionary with unit templates, by the id stored in the template.
func populate_master() -> void:
    for template in resource.all:
        master[template.id] = template
#endregion
