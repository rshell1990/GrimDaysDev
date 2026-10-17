extends Control


## Opens the patch-notes panel through the UI director.
func _on_patch_notes_button_button_up() -> void:
    UIDirector.show_patch_notes()
