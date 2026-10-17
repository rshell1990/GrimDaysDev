extends Node

## Master list of spine skeletons that the spine sprites have.  It takes a
## resource list of spine skeletons and then sorts them into a dictionary that
## can be refrenced to get information about the animation throughout the project.

## The resource file containing information about the spine skeletons.
var resource: MasterSkeletonDictionary

## The dictionary to be accessed by other parts of the project.
var master: Dictionary


## Requests a threaded load of the master skeleton dictionary, then retrieves the resource.
## Retrieving it can wait until loading completes.
func _enter_tree() -> void:
    var load_threaded = ResourceLoader.load_threaded_request(
        "res://GrimDaysVN/resources/spine/master_skeleton_dictionary.tres", "", true
    )
    resource = ResourceLoader.load_threaded_get(
        "res://GrimDaysVN/resources/spine/master_skeleton_dictionary.tres"
    )


## Builds this repository’s lookup table from its assigned resources when the node is ready.
func _ready():
    if resource == null:
        return
    for id in resource.directory:
        var spine_data: String = resource.directory[id]
        master[id] = spine_data
