extends Node

## Lookup table for kinds; keys select the corresponding stored values.
var kinds: Dictionary = {}
## Lookup table for resources; keys select the corresponding stored values.
var resources: Dictionary = {}


# Called when the node enters the scene tree for the first time.
## Collects each child repository's lookup table and any source resource it exposes.
func _ready() -> void:
    if not get_child_count():
        return
    for child in get_children():
        #assert(not child.master.is_empty())
        kinds[child.name] = child.master
        var properties = child.get_property_list()
        for property in properties:
            if property.name == "resource":
                resources[child.name] = child.resource
                break


## Returns the stored path for the requested category and entry. Both keys must exist; assertions
## check them.
func get_resource_path(kind: String, entry: String) -> String:
    assert(kinds.has(kind))
    assert(kinds[kind].has(entry))
    return kinds[kind][entry]


## Returns the requested entry, loading it without reusing the deep resource cache when the entry is
## a path string. Returns null for a missing entry; the category must exist.
func get_info(kind: String, entry: Variant):
    assert(kinds.has(kind))
    if not kinds[kind].has(entry):
        return null
    var info = kinds[kind][entry]
    if typeof(info) == TYPE_STRING:
        info = ResourceLoader.load(info, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
    return info


## Returns the category's source resource, or no value when no source resources have been collected.
## The category must exist.
func get_resource(kind: String):
    assert(kinds.has(kind))
    if resources.is_empty():
        return
    return resources[kind]


## Returns the child repository node whose name matches the category, or null if none matches.
func get_repository(kind: String):
    for child in get_children():
        if child.name == kind:
            return child

    return null
