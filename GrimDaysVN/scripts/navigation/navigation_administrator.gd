## NavigationAdministrator controls.
class_name NavigationAdministrator
extends Node

## The Navigation Director, manages the state of the navigation system.
var director: NavigationDirector
# TODO: Keep working on this.  Add way to handle commands to change the location/dimension.
## Looks up the function to run for each supported command name.
var handle_command_by_type: Dictionary


## Waits for any current dialogue animation, then runs the handler for the lowercase command name
## with the remaining arguments.
func command(arg: Variant) -> void:
    var final_args = arg.slice(1, arg.size())
    var parsed_arg = arg[Basics.FIRST].to_lower()
    if Dialogic.Animations.is_animating():
        await Dialogic.Animations.finished
    handle_command_by_type[parsed_arg].call(final_args)


## Relay the set location command to the navigation director.
func set_location(new_location: StringName) -> void:
    set_director()
    director.set_location(new_location)


## Relay the set dimension command to the navigation director.
func set_dimension(new_dimension: DIMENSIONS) -> void:
    set_director()
    director.set_dimension(new_dimension)


## From the command, get the location's alias and set the location to the returned LOCATION value.
func get_location(args: Array) -> void:
    var data: Dictionary = SystemHelpers.args_to_dict(args)
    var location = SystemAdministrators.get_location_from_alias(data.name)
    if location.is_empty():
        return
    set_location(location)


## Get the dimension alias from the command and set the new DIMENSION value.
func get_dimension(args: Array) -> void:
    var data: Dictionary = SystemHelpers.args_to_dict(args)
    var dimension = SystemHelpers.get_location_from_alias(data.name)
    set_dimension(dimension)


## Run as part of the node's initialization process.
func _ready() -> void:
    set_director()
    handle_command_by_type = {
        NavigationCommands.LOCATION: get_location,
        NavigationCommands.DIMENSION: get_dimension,
    }


## Return the current dimension set on the director.
func current_dimension() -> DIMENSIONS:
    set_director()
    return director.dimension


## Return the current location set on the director.
func current_location() -> StringName:
    set_director()
    return director.location


## Set the navigation director if it hasn't been set yet.
func set_director() -> void:
    if director == null:
        director = get_child(0)


## The 'dimensions' that the game takes place in.
enum DIMENSIONS { PRIME, DARK }

## Legacy location IDs still referenced by runtime defaults or test fixtures.
## Current story labels are maintained by SystemAdministratorsBase.STORY_LOCATION_NAMES.
const LOCATIONS: Array[StringName] = [
    "NovarasChildhoodHomeLivingRoom",
    "NovarasOrphanageCellar",
    "NovarasOrphanageOffice",
]
