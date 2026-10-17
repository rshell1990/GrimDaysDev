extends Control
class_name FontOperator

## List of nodes with normal text used by this script.
@export var nodes_with_normal_text: Array[Control]
## List of nodes with bold text used by this script.
@export var nodes_with_bold_text: Array[Control]
## List of nodes with italic text used by this script.
@export var nodes_with_italic_text: Array[Control]
## List of nodes with all text used by this script.
@export var nodes_with_all_text: Array[Control]
## List of nodes to scale text used by this script.
@export var nodes_to_scale_text: Array[Control]

## List of original text sizes used by this script.
var original_text_sizes: Array[int]


## When the node is ready, this function connects responses to
## [code]VNSignalBus.font_scale_changed[/code], [code]VNSignalBus.on_ui_update[/code]; adds
## [code]font_size[/code] to [code]original_text_sizes[/code]; sets [code]original_text_sizes[/code]
## to [code][][/code].
func _ready() -> void:
    original_text_sizes = []
    for scalable_text in nodes_to_scale_text:
        var font_size = (
            scalable_text.get_theme_font_size("font_size")
            if scalable_text not in nodes_with_all_text
            else scalable_text.get_theme_font_size("normal_font_size")
        )
        original_text_sizes.append(font_size)
    VNSignalBus.font_scale_changed.connect(on_font_scale_changed)
    VNSignalBus.on_ui_update.connect(on_ui_update)
    on_ui_update()


## Updates the displayed fonts to match the newly selected font setting.
func on_font_changed(new_font: String) -> void:
    change_nodes_with_normal_text(new_font)
    change_nodes_with_bold_text(new_font)
    change_nodes_with_italic_text(new_font)
    change_nodes_with_all_text(new_font)


## Updates the displayed font sizes to match the new scale.
func on_font_scale_changed(new_scale: float) -> void:
    for x in range(0, len(nodes_to_scale_text)):
        var scalable_text = nodes_to_scale_text[x] as Control
        var original_text_size: int = original_text_sizes[x]
        var new_text_size: float = floorf(original_text_size * new_scale)
        if scalable_text in nodes_with_all_text:
            scalable_text.add_theme_font_size_override("normal_font_size", int(new_text_size))
            scalable_text.add_theme_font_size_override("bold_font_size", int(new_text_size))
            scalable_text.add_theme_font_size_override("italics_font_size", int(new_text_size))
            scalable_text.add_theme_font_size_override("bold_italics_font_size", int(new_text_size))
        else:
            scalable_text.add_theme_font_size_override("font_size", int(new_text_size))


## Applies the selected regular font to a text control.
func change_nodes_with_normal_text(new_font: String) -> void:
    for normal_node in nodes_with_normal_text:
        var text_holder = normal_node
        text_holder.add_theme_font_override("font", Repositories.get_info(RepositoryTypes.FONTS, new_font).normal)


## Applies the selected bold font to a text control.
func change_nodes_with_bold_text(new_font: String) -> void:
    for bold_node in nodes_with_bold_text:
        var text_holder = bold_node
        text_holder.add_theme_font_override("font", Repositories.get_info(RepositoryTypes.FONTS, new_font).bold)


## Applies the selected italic font to a text control.
func change_nodes_with_italic_text(new_font: String) -> void:
    for italic_node in nodes_with_italic_text:
        var text_holder = italic_node
        text_holder.add_theme_font_override("font", Repositories.get_info(RepositoryTypes.FONTS, new_font).italics)


## Applies regular, bold and italic font choices to a rich-text control.
func change_nodes_with_all_text(new_font: String) -> void:
    for normal_node in nodes_with_all_text:
        var text_holder = normal_node
        text_holder.add_theme_font_override(
            "normal_font", Repositories.get_info(RepositoryTypes.FONTS, new_font).normal
        )
        text_holder.add_theme_font_override(
            "italics_font", Repositories.get_info(RepositoryTypes.FONTS, new_font).italics
        )
        text_holder.add_theme_font_override(
            "bold_italics_font", Repositories.get_info(RepositoryTypes.FONTS, new_font).combo
        )
        text_holder.add_theme_font_override("bold_font", Repositories.get_info(RepositoryTypes.FONTS, new_font).bold)


## Refreshes text colors after a UI setting changes.
func on_ui_update() -> void:
    update_text_colors(nodes_with_normal_text)
    update_text_colors(nodes_with_bold_text)
    update_text_colors(nodes_with_italic_text)
    update_text_colors(nodes_with_all_text)


## Applies text and outline colors for the selected palette and current dimension.
func update_text_colors(node_list: Array) -> void:
    for text_holder in node_list:
        text_holder.add_theme_color_override(
            "font_color",
            (
                SM_Globals.user_prefs.normal_text_color
                if SystemAdministrators.current_dimension() == NavigationAdministrator.DIMENSIONS.PRIME
                else SM_Globals.user_prefs.dark_text_color
            )
        )
        text_holder.add_theme_color_override(
            "font_outline_color",
            (
                SM_Globals.user_prefs.normal_outline_color
                if SystemAdministrators.current_dimension() == NavigationAdministrator.DIMENSIONS.PRIME
                else SM_Globals.user_prefs.dark_outline_color
            )
        )
