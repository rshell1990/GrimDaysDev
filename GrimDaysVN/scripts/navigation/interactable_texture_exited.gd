extends Node
## Restores an interaction's normal appearance when the pointer leaves.
class_name InteractableExited
## Image used for highlight.
@export var highlight_texture: Sprite2D
## Scene object used for label.
@export var label: Label


## Changes the mouse pointer image; sets [code]highlight_texture.visible[/code] to false; sets
## [code]label.modulate.a[/code] to [code]0.5[/code].
func execute():
    if highlight_texture != null:
        highlight_texture.visible = false
    Input.set_custom_mouse_cursor(null)
    if label:
        label.modulate.a = 0.5
