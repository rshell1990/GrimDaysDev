extends Node
class_name VNItemRepository

@export var resource: VNItemTemplates
var master: Dictionary = {}

func _ready() -> void:
    if not resource:
        push_error("The item repository requires an item template collection.")
        return
    for item in resource.all:
        if not item or item.id == null:
            push_error("The item collection contains a missing item or item ID.")
            continue
        if master.has(item.id):
            push_error("Duplicate item ID in item collection: %s." % item.id)
            continue
        master[item.id] = item
