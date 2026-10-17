extends Control


# Called when the node enters the scene tree for the first time.
## When the node is ready, this function connects responses to
## [code]VNSignalBus.on_ui_update[/code].
func _ready():
    var bg_color = SystemHelpers.current_accent_color()
    self_modulate = bg_color
    VNSignalBus.on_ui_update.connect(on_ui_update)


## Tints the line with the currently selected accent color.
func on_ui_update():
    var bg_color = SystemHelpers.current_accent_color()
    self_modulate = bg_color
