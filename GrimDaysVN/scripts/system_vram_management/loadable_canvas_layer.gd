# Editor configuration for LoadableCanvasLayer.
@icon("res://GrimDays/assets/visuals/editor_icons/large-paint-brush.svg")
extends CanvasLayer
class_name LoadableCanvasLayer


## Returns whether this canvas layer is visible.
func get_state() -> Dictionary:
    var state: Dictionary
    state = {"visible": visible}
    return state


## Restores whether this canvas layer is visible from the supplied state.
func restore_state(state: Dictionary) -> void:
    visible = state.visible
