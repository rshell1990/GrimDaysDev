extends Resource
class_name VNItemTemplates

@export var all: Array[VNItemTemplate] = []

func get_item(item_id: Variant) -> VNItemTemplate:
    for item in all:
        if item and item.id == item_id:
            return item
    return null
