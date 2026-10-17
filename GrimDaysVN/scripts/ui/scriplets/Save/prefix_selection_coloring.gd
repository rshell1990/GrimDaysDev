extends MarginContainer

## Color used for accent color.
var accent_color: Color
## Scene control for background, used to display or change the related setting.
@export var background: OptionButton
## Scene object used for frame.
@export var frame: Panel


## When the node is ready, this function connects responses to
## [code]VNSignalBus.on_ui_update[/code].
func _ready():
    SystemHelpers.color_self(background, frame)
    VNSignalBus.on_ui_update.connect(color_self)


## Applies the selected UI color scheme to this control's background and frame.
func color_self():
    SystemHelpers.color_self(background, frame)


## Updates [code]accent_color[/code] using [code]SystemHelpers.current_accent_color[/code]; sets
## [code]background.modulate[/code] to [code]accent_color[/code].
func _on_mouse_entered() -> void:
    accent_color = SystemHelpers.current_accent_color()
    background.modulate = accent_color


## Updates [code]background.modulate[/code] using [code]SystemHelpers.current_text_color[/code].
func _on_mouse_exited() -> void:
    background.modulate = SystemHelpers.current_text_color()
