extends Node
## Coordinates resource battle repositories behavior for the battle system.
class_name ResourceBattleRepositories
#region BattleRepository
## A global class, that indexes it's children of different kinds of BattleRepository.
## These children
## BattleRepository contain resources that may need to be accessed
## from multiple parts of the script.
##
##
##
#endregion
#region VARIABLES
## All the different types of stored resources, stores the information from
## the master dictionary of the resource.
var kinds: Dictionary = {}
## All the different types of stored resources, stores the original resource.
var resources: Dictionary = {}
#endregion


#region MAIN
## Called when the node enters the scene tree for the first time.
func _ready() -> void:
    for child in get_children():
        if child.master.is_empty():
            continue
        kinds[child.name] = child.master
        resources[child.name] = child.resource


## Returns a specific entry from the master dictionary of a repository.
func get_info(kind, entry) -> Variant:
    return kinds[kind][entry]


## Returns the original resource used to create the master dictionary.
func get_resource(kind) -> Variant:
    return resources[kind]


## Returns the master dictionary of a repository.
func get_repository(kind) -> Dictionary:
    return kinds[kind]


#endregion

#region CONSTANTS
## The sound effect repository.
const AUDIO_FX: StringName = &"AudioFX"
## The battle equipment repository.
const BATTLE_EQUIPMENT: StringName = &"BattleEquipment"

## Fixed battle unit templates value shared by all resource battle repositories instances.
const BATTLE_UNIT_TEMPLATES: StringName = &"BattleUnits"
## Fixed unit skills value shared by all resource battle repositories instances.
const UNIT_SKILLS: StringName = &"BattleUnitSkills"
#endregion
