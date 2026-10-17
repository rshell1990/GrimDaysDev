# Editor configuration for LoadableTitleCard.
@icon("res://GrimDays/assets/visuals/editor_icons/bookmark.svg")
extends Control
class_name LoadableTitleCard

## Scene node used for vignette, found when this node is ready.
@onready var vignette: TextureRect = $vignette
## Scene node used for background, found when this node is ready.
@onready var background: ColorRect = $background
# Called when the node enters the scene tree for the first time.
#func _ready() -> void:
#var vignette_material = vignette.material as ShaderMaterial
#var current_color = SystemHelpers.current_accent_color() as Color
#var to_adjust: Color = current_color
#var darkened: Color = to_adjust.darkened(0.85)
#darkened.h += 0.1
#
#vignette_material.set_shader_parameter("vignette_rgb", darkened)
#
#background.self_modulate = current_color


## Reveals the screen.
func set_message(message: String) -> void:
    visible = true
    var rich_text_label: RichTextLabel = get_child(1)
    rich_text_label.text = (
        "[center][i]"
        + message
        + "[ghost freq=3.0 span=100].[/ghost][ghost freq=3.2 span=100].[/ghost][ghost freq=3.4 span=100].[/ghost]"
    )
    UIDirector.reveal_screen()


## Asks the title-card display to hide its current message.
func hide_title_card() -> void:
    UIDirector.cover_screen()
    await get_tree().create_timer(VNAnimationTimes.LONG).timeout
    visible = false


## Returns remembered values for visible, modulate, self modulate, global position, for saving or
## later restoration.
func get_state() -> Dictionary:
    var state: Dictionary
    state = {
        "visible": visible, "modulate": modulate, "self_modulate": self_modulate, "global_position": global_position
    }
    if not material:
        return state
    if not material is ShaderMaterial:
        return state

    var shader = material.shader
    var shader_uniforms: Array = shader.get_shader_uniform_list()
    for uniform_information in shader_uniforms:
        state.set(uniform_information.name, material.get_shader_parameter(uniform_information.name))

    return state


## Applies saved values to this object’s display or resource settings, including shader settings
## when present.
func restore_state(state: Dictionary) -> void:
    visible = state.visible
    modulate = state.modulate
    self_modulate = state.self_modulate
    global_position = state.global_position

    if not material:
        return
    if not material is ShaderMaterial:
        return

    var shader = material.shader
    var shader_uniforms: Array = shader.get_shader_uniform_list()
    for uniform_information in shader_uniforms:
        if not state.has(uniform_information.name):
            continue
        material.set_shader_parameter(uniform_information.name, state[uniform_information.name])
