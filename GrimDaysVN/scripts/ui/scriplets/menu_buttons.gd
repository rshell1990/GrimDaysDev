extends Control

## Color used for accent color.
@export var accent_color: Color
## Color used for default color.
@export var default_color: Color
## Scene object used for label.
@export var label: Label
## Caption shown on the button; keep the label node itself text-free so instances only set this.
@export var label_text: String:
    set(value):
        label_text = value
        if not is_node_ready():
            return
        label.text = label_text


## When the node is ready, this function connects responses to [code]self.mouse_entered[/code],
## [code]self.mouse_exited[/code].
func _ready():
    self.mouse_entered.connect(_on_mouse_entered)
    self.mouse_exited.connect(_on_mouse_exited)
    label.text = label_text
    label.add_theme_color_override("font_color", default_color)


## Uses the accent text color while the pointer is over an enabled menu button.
func _on_mouse_entered() -> void:
    if process_mode == PROCESS_MODE_DISABLED:
        return
    label.add_theme_color_override("font_color", accent_color)


## Restores the normal text color when the pointer leaves an enabled menu button.
func _on_mouse_exited() -> void:
    if process_mode == PROCESS_MODE_DISABLED:
        return
    label.add_theme_color_override("font_color", default_color)
