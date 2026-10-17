extends Control

## Scene object used for background.
@export var background: Control
## Scene object used for frame.
@export var frame: Panel


## When the node is ready, this function connects responses to
## [code]VNSignalBus.on_ui_update[/code].
func _ready():
    VNSignalBus.on_ui_update.connect(color_self)
    color_self()


## Applies the selected UI color scheme to this control's background and frame.
func color_self():
    SystemHelpers.color_self(background, frame)
    background.self_modulate.a = 1.0
