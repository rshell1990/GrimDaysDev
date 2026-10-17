extends "res://addons/dialogic/Modules/TextInput/subsystem_text_input.gd"


## Opens a text-entry prompt using the supplied label, default value, placeholder and empty-input
## policy.
func show_input(
    text := "",
    caller: Variant = null,
    default := "",
    placeholder := "",
    allow_empty := false
) -> void:
    var input_nodes = get_tree().get_nodes_in_group("dialogic_text_input")
    for node in input_nodes:
        node.show()
        if node.has_method("set_allow_empty"):
            node.set_allow_empty(allow_empty)
        if node.has_method("set_text"):
            node.set_text(text)
        if node.has_method("set_default"):
            node.set_default(default)
        if node.has_method("set_placeholder"):
            node.set_placeholder(placeholder)
    input_shown.emit(
        {
            "text": text,
            "default": default,
            "placeholder": placeholder,
            "allow_empty": allow_empty,
            "caller": caller
        }
    )
