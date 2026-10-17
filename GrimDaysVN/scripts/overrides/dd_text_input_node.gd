## Custom text-input control that submits the entered value.
class_name DDTextInputNode
extends DialogicNode_TextInput


## Submits the current text-input value through the custom input confirmation path.
func _on_confirmation_button_pressed(text := "") -> void:
    if get_node(input_line_edit) is LineEdit:
        if !get_node(input_line_edit).text.is_empty() or _allow_empty:
            DDTextInput.input_confirmed.emit(get_node(input_line_edit).text)
