extends Button

## Notification for color changed. Supplies [code]color[/code] to connected functions.
signal color_changed(color)

## Text representation of the color shown by this swatch.
var color_code: String


## When the node is ready, this function connects responses to [code]pressed[/code].
func _ready():
    pressed.connect(on_pressed)


## Sets [code]color_code[/code] to [code]color[/code]; updates [code]normal.bg_color[/code] using
## [code]Color.from_string[/code]; updates [code]hover.bg_color[/code] using
## [code]Color.from_string[/code].
func on_create(color) -> void:
    color_code = color
    var normal: StyleBoxFlat = get_theme_stylebox("normal").duplicate()
    normal.bg_color = Color.from_string(color_code, Color.WHITE)
    add_theme_stylebox_override("normal", normal)

    var hover: StyleBoxFlat = get_theme_stylebox("hover").duplicate()
    hover.bg_color = Color.from_string(color_code, Color.WHITE).lightened(0.33)
    add_theme_stylebox_override("hover", hover)


## Sends [code]color_changed[/code] notifications.
func on_pressed() -> void:
    color_changed.emit(color_code)
