extends Panel

## Scene object used for bg.
@export var bg: Panel
## Scene object used for frame.
@export var frame: Panel
## Scene object used for label.
@export var label: Label
## Scene object used for fight info.
@export var fight_info: Node

## Color used for accent color.
var accent_color: Color


## When the node is ready, this function connects responses to [code]self.mouse_entered[/code],
## [code]self.mouse_exited[/code], [code]VNSignalBus.on_ui_update[/code].
func _ready():
    self.mouse_entered.connect(_on_mouse_entered)
    self.mouse_exited.connect(_on_mouse_exited)
    VNSignalBus.on_ui_update.connect(color_self)
    color_self()


## Applies the selected UI color scheme to this control's background and frame.
func color_self():
    SystemHelpers.color_self(bg, frame)


## Updates [code]accent_color[/code] using [code]SystemHelpers.current_accent_color[/code]; sets
## [code]label.modulate[/code] to [code]accent_color[/code].
func _on_mouse_entered() -> void:
    if process_mode == PROCESS_MODE_DISABLED:
        return
    accent_color = SystemHelpers.current_accent_color()
    label.modulate = accent_color


## Updates [code]label.modulate[/code] using [code]SystemHelpers.current_text_color[/code].
func _on_mouse_exited() -> void:
    if process_mode == PROCESS_MODE_DISABLED:
        return
    label.modulate = SystemHelpers.current_text_color()
