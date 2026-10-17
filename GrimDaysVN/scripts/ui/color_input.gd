extends LineEdit

## Color used for accent color.
var accent_color: Color


## When the node is ready, this function connects responses to
## [code]VNSignalBus.on_ui_update[/code].
func _ready():
    SystemHelpers.color_self(self, self)
    VNSignalBus.on_ui_update.connect(color_self)


## Applies the selected UI color scheme to this control's background and frame.
func color_self():
    SystemHelpers.color_self(self, self)
