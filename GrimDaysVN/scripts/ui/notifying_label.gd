extends Label
class_name NotifyingLabel
## Notification for text changed.
signal text_changed


## Updates this label's text and announces the change to controls mirroring it.
func update_text(new_text: String) -> void:
    text = new_text
    text_changed.emit()
