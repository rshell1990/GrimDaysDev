extends TextureRect
## Scene object used for root.
@export var root: Node
#TODO: Add code to change this icon, based upon the name in 'NameLabel'


## When the node enters the scene, this function connects responses to
## [code]root.text_changed[/code].
func _enter_tree() -> void:
    root.text_changed.connect(on_text_changed)
    on_text_changed(root.get_name_label().text)


## Uses the speaker text to look up a history portrait. Hides this icon if none exists; otherwise
## applies the portrait texture and position.
func on_text_changed(changed_text: String) -> void:
    var new_text = changed_text.replace(":", "").strip_edges()
    var portrait = Repositories.get_info("HistoryPortraits", new_text)
    if portrait == null:
        visible = false
        return
    texture = portrait.texture
    position = portrait.position
