extends CanvasLayer

## Whether ready to advance is currently enabled or true.
var ready_to_advance: bool = true
## Index of the tutorial step currently being displayed.
var current_step: int = 0
## List of animations in order used by this script.
var animations_in_order: Array[String] = [
    "fade_in",
    "dismiss_battle_screen_breakdown",
    "show_slider_breakdown_1",
    "show_slider_breakdown_2",
    "dismiss_slider_breakdown",
    "show_spinner_breakdown_1",
    "show_spinner_breakdown_2",
    "show_spinner_breakdown_3",
    "dismiss_spinner",
    "recover_show",
    "dismiss_recover"
]


## When the node is ready, this function connects responses to
## [code]AnimationPlayer.animation_finished[/code].
func _ready() -> void:
    $AnimationPlayer.animation_finished.connect(on_animation_finish)


## Sets [code]ready_to_advance[/code] to false.
func _on_next_button_up() -> void:
    if not ready_to_advance:
        return
    $AnimationPlayer.play(animations_in_order[current_step])
    ready_to_advance = false


## Increases [code]current_step[/code] by [code]1[/code]; sets [code]ready_to_advance[/code] to
## true.
func on_animation_finish(_name):
    current_step += 1
    ready_to_advance = true


## Plays the last configured tutorial animation when the close button is released.
func _on_quit_button_up() -> void:
    $AnimationPlayer.play(animations_in_order[Basics.LAST])
