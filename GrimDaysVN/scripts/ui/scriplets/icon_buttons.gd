extends Control

## Color used for accent color.
var accent_color: Color
## Scene control for icon, used to display or change the related setting.
var icon: Sprite2D
## Whether am toggled is currently enabled or true.
var am_toggled: bool = false


## When the node is ready, this function connects responses to [code]self.mouse_entered[/code],
## [code]self.mouse_exited[/code], [code]button.toggled[/code],
## [code]VNSignalBus.on_ui_update[/code]; sets [code]icon[/code] to
## [code]get_child(0).get_child(1)[/code].
func _ready():
    icon = get_child(0).get_child(1)
    self.mouse_entered.connect(_on_mouse_entered)
    self.mouse_exited.connect(_on_mouse_exited)
    var button = get_node(".") as Button
    button.toggled.connect(_on_toggled)
    SystemHelpers.color_self(self, get_child(1))
    VNSignalBus.on_ui_update.connect(color_self)


## Applies the selected UI color scheme to this control's background and frame.
func color_self():
    SystemHelpers.color_self(self, get_child(1))


## Updates [code]accent_color[/code] using [code]SystemHelpers.current_accent_color[/code]; sets
## [code]frame.self_modulate[/code] to [code]accent_color[/code]; sets [code]icon.modulate[/code] to
## [code]accent_color[/code].
func _on_mouse_entered() -> void:
    accent_color = SystemHelpers.current_accent_color()
    if am_toggled:
        var frame = get_child(1)
        frame.self_modulate = accent_color
        return
    icon.modulate = accent_color


## Updates [code]frame.self_modulate[/code] using [code]SystemHelpers.current_accent_color[/code];
## sets [code]frame.self_modulate.h[/code] to [code]frame.self_modulate.h - (ColorCodes.HUE_SHIFT *
## 2.5)[/code]; updates [code]icon.modulate[/code] using
## [code]SystemHelpers.current_text_color[/code].
func _on_mouse_exited() -> void:
    if am_toggled:
        var frame = get_child(1)
        frame.self_modulate = SystemHelpers.current_accent_color()
        frame.self_modulate.h = frame.self_modulate.h - (ColorCodes.HUE_SHIFT * 2.5)
        frame.self_modulate.darkened(ColorCodes.DARKEN_BY)
        return
    icon.modulate = SystemHelpers.current_text_color()


## Sets [code]am_toggled[/code] to true; updates [code]accent_color[/code] using
## [code]SystemHelpers.current_accent_color[/code]; sets [code]modulated_color.h[/code] to
## [code]modulated_color.h + (ColorCodes.HUE_SHIFT * 2.5)[/code].
func _on_toggled(is_toggled):
    if is_toggled:
        am_toggled = true
        accent_color = SystemHelpers.current_accent_color()
        var modulated_color: Color = accent_color
        modulated_color.h = modulated_color.h + (ColorCodes.HUE_SHIFT * 2.5)
        modulated_color.lightened(ColorCodes.LIGHTEN_BY)
        icon.modulate = modulated_color
        var frame = get_child(1)
        frame.self_modulate.h = frame.self_modulate.h - (ColorCodes.HUE_SHIFT * 2.5)
        frame.self_modulate.darkened(ColorCodes.DARKEN_BY)
    else:
        am_toggled = false
        icon.modulate = SystemHelpers.current_text_color()
        color_self()
