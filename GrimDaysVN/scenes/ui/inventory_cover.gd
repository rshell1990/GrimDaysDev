extends ColorRect
## Scene object used for temp inventory.
@export var temp_inventory: Node


## When the node is ready, this function connects responses to [code]visibility_changed[/code].
func _ready() -> void:
    visibility_changed.connect(on_visibility_change)


## Refreshes the temporary inventory interface when the cover becomes visible.
func on_visibility_change() -> void:
    if visible:
        temp_inventory.init_ui()
