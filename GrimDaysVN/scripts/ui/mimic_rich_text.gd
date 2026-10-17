extends RichTextLabel
## Stored watching used by this script’s update and input handling.
@export var watching: DialogicNode_DialogText


## Copies the watched label's text and visible-character count when the text is nonempty.
func _enter_tree() -> void:
    if watching.text.is_empty():
        return
    text = watching.text
    visible_characters = watching.visible_characters


## When the node is ready, this function connects responses to
## [code]Dialogic.Text.about_to_show_text[/code].
func _ready() -> void:
    Dialogic.Text.about_to_show_text.connect(on_about_to_show)


## Clears the mirrored text before the next dialogue text is displayed.
func on_about_to_show(_info: Dictionary) -> void:
    text = ""


## Keeps the mirrored text and visible-character count in sync on physics updates, leaving them
## unchanged while the watched text is empty.
func _physics_process(delta: float) -> void:
    if watching.text.is_empty():
        return
    text = watching.text
    visible_characters = watching.visible_characters
