extends Node
## Contains information about all the scenes that can be called from the script, providing an easy
## way to reference them from other parts of the project.  These template scenes are instantiated
## as a new scene and then added to the existing scene tree.  Usually by the Scene Manager but
## sometimes not.

## File or resource path used for storage file.
const STORAGE_FILE = "res://GrimDaysVN/resources/scene_paths.tres"
## File or resource path used for production battle scene.
const PRODUCTION_BATTLE_SCENE = "res://GrimDaysVN/scenes/root/battle.tscn"

## The dictionary accessed by other parts of the project.
var master: Dictionary


## Builds this repository’s lookup table from its assigned resources when the node is ready.
func _ready():
    var resources = (
        FileFinder.find("res://", ["tscn"])
        if OS.is_debug_build()
        else ResourceLoader.load(STORAGE_FILE, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP).resources
    )
    if OS.is_debug_build():
        var resource = ResourcePaths.new()
        resource.resources = resources
        # Success is 0, so when it's not 0 the save has failed.
        assert(not ResourceSaver.save(resource, STORAGE_FILE))
    for file_path in resources:
        if not file_path.contains("GrimDays"):
            continue
        var file_name = file_path.split("/")[-1].replace(".tscn", "")
        master[file_name] = file_path
    # The stored release manifest predates the battle module. Keep this explicit
    # entry so production and debug builds resolve the same stable scene key.
    master["battle"] = PRODUCTION_BATTLE_SCENE
