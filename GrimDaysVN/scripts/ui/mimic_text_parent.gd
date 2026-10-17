extends Label
class_name MimicLabel
## Parent label whose text is mirrored used by this node.
var parent: NotifyingLabel


## When the node enters the scene, this function connects responses to
## [code]parent.text_changed[/code]; sets [code]parent[/code] to [code]get_parent()[/code].
func _enter_tree() -> void:
    parent = get_parent()
    parent.text_changed.connect(on_text_changed)
    on_text_changed()


## Copies the parent label's text and visible-character count to this label.
func on_text_changed() -> void:
    text = parent.text
    visible_characters = parent.visible_characters
