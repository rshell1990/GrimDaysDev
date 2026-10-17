extends Container

## Notification for text changed. Supplies [code]new_text[/code] to connected functions.
signal text_changed(new_text)


## Returns the text control used by this dialogue-history entry.
func get_text_box() -> RichTextLabel:
    return %TextBox


## Returns the speaker-name label used by this dialogue-history entry.
func get_name_label() -> Label:
    return %NameLabel


## Returns the portrait control used by this dialogue-history entry.
func get_icon() -> TextureRect:
    return %Icon


## Fills a history entry from its dialogue information, showing or hiding speaker details as
## appropriate, and announces the text change.
func load_info(text: String, character: String = "", character_color: Color = Color(), icon: Texture = null) -> void:
    get_text_box().text = text
    var name_label: Label = get_name_label()
    if character:
        name_label.text = character
        text_changed.emit(character)
        name_label.add_theme_color_override("font_color", character_color)
        name_label.show()
    else:
        name_label.hide()

    var icon_node: TextureRect = get_icon()
    if icon == null:
        icon_node.hide()
    else:
        icon_node.show()
        icon_node.texture = icon
