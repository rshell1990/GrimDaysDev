extends Control


## Shows the patch-notes panel.
func unhide() -> void:
    show()


## Hides the patch-notes panel.
func vanish() -> void:
    hide()


## Closes the patch-notes panel when its close button is released.
func _on_quit_button_up() -> void:
    vanish()
