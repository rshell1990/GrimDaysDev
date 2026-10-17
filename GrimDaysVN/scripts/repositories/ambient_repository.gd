## Builds lookup entries for ambient resources so other scripts can find them by ID.
class_name AmbientRepository
extends Node

## File or resource path used for storage file.
const STORAGE_FILE = "res://GrimDaysVN/resources/audio/ambient_tracks.tres"

## Lookup table built from this repository’s source resources for other systems to query.
var master: Dictionary = {}


## Builds this repository’s lookup table from its assigned resources when the node is ready.
func _ready() -> void:
    var resources: PackedStringArray = (
        FileFinder.find("res://GrimDaysVN/resources/audio/ambient/", ["tres"])
        if OS.is_debug_build()
        else ResourceLoader.load(STORAGE_FILE, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP).resources
    )
    if OS.is_debug_build():
        var resource = ResourcePaths.new()
        resource.resources = resources
        # Success is 0, so when it's not 0 the save has failed.
        assert(not ResourceSaver.save(resource, STORAGE_FILE))

    for file_path in resources:
        var file_name = file_path.split("/")[-1].replace(".tres", "")
        master[file_name] = file_path
