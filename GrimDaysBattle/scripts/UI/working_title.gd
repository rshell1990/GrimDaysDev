extends Node
## Configures the swap target used by this working title.
@export var swap_target: PackedScene


## Initializes tree-dependent state as this node enters the scene tree.
func _enter_tree() -> void:
    if not UIDirector.is_node_ready():
        await UIDirector.ready
    UIDirector.reveal_screen()
    UIDirector.fade_flag_hide()


## Handles the start button up notification for this working title.
func _on_start_button_up() -> void:
    get_tree().change_scene_to_packed(swap_target)
