extends DialogicNode_ChoiceButton
class_name DDDNChoiceButton
## Scene object used for background.
var background: Control
## Scene object used for frame.
var frame: Control


## When the node is ready, this function connects responses to
## [code]VNSignalBus.on_ui_update[/code]; sets [code]background[/code] to [code]self[/code]; sets
## [code]frame[/code] to [code]get_child(1)[/code].
func _ready() -> void:
    super()
    background = self
    frame = get_child(1)
    VNSignalBus.on_ui_update.connect(color_self)
    color_self()
    if text_node == null:
        text_node = get_child(0).get_child(0)


## Applies the selected UI color scheme to this control's background and frame.
func color_self() -> void:
    SystemHelpers.color_self(background, frame)
    background.self_modulate.a = 1.0


## Updates choice text and scales minimum height by its line count while preserving minimum width.
func set_choice_text(new_text: String) -> void:
    super(new_text)
    var line_count = text_node.get_line_count()
    var root = get_parent().get_parent()
    custom_minimum_size.y = root.boxes_min_size.y * line_count
