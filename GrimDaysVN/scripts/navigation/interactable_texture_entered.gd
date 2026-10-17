extends Node
## Shows an interaction's hover appearance and pointer feedback.
class_name InteractableEntered

## Image used for highlight.
@export var highlight_texture: Sprite2D
## Scene object used for label.
@export var label: Label
## Image used for mouse.
@export var mouse_texture: Texture2D
## Image prepared for use as the custom mouse pointer.
var mouse_cursor: Image


## When the node is ready, this function updates [code]mouse_cursor[/code] using
## [code]mouse_texture.get_image[/code].
func _ready() -> void:
    mouse_cursor = mouse_texture.get_image()


## Sets [code]label.modulate.a[/code] to [code]1.0[/code]; sets
## [code]highlight_texture.visible[/code] to true.
@warning_ignore("narrowing_conversion")
func execute() -> void:
    var screen_ratio: float = get_viewport().size.x / 1920.0
    #SystemHelpers.print(get_parent().name)
    mouse_cursor.resize(64 * screen_ratio, 64 * screen_ratio)
    if label:
        label.modulate.a = 1.0
    if highlight_texture != null:
        highlight_texture.visible = true
    Input.set_custom_mouse_cursor(
        mouse_cursor, Input.CURSOR_ARROW, Vector2(32 * screen_ratio, 32 * screen_ratio)
    )
