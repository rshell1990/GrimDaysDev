extends ColorRect
## Game mode remembered before entering text-input mode.
var previous_state: GameManagerStates.STATES


## Matches this control's visibility to the neighboring text-input layer.
func _on_text_input_layer_visibility_changed() -> void:
    var sibling = get_parent().get_child(1)
    if sibling.visible:
        visible = true
    else:
        visible = false
