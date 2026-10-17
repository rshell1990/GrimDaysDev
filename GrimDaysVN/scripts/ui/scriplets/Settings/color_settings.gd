extends GridContainer

## Notification for ui updated.
signal ui_updated
## Scene object used for normal accent preset container.
@export var normal_accent_preset_container: HBoxContainer
## Scene object used for normal text preset container.
@export var normal_text_preset_container: HBoxContainer
## Scene object used for normal outline preset container.
@export var normal_outline_preset_container: HBoxContainer
## Scene object used for dark accent preset container.
@export var dark_accent_preset_container: HBoxContainer
## Scene object used for dark text preset container.
@export var dark_text_preset_container: HBoxContainer
## Scene object used for dark outline preset container.
@export var dark_outline_preset_container: HBoxContainer
## Scene control for normal accent color picker, used to display or change the related setting.
@export var normal_accent_color_picker: ColorPickerButton
## Scene control for normal text color picker, used to display or change the related setting.
@export var normal_text_color_picker: ColorPickerButton
## Scene control for normal outline color picker, used to display or change the related setting.
@export var normal_outline_color_picker: ColorPickerButton
## Scene control for dark accent color picker, used to display or change the related setting.
@export var dark_accent_color_picker: ColorPickerButton
## Scene control for dark text color picker, used to display or change the related setting.
@export var dark_text_color_picker: ColorPickerButton
## Scene control for dark outline color picker, used to display or change the related setting.
@export var dark_outline_color_picker: ColorPickerButton
## Scene control for background opacity slider, used to display or change the related setting.
@export var background_opacity_slider: HSlider
## Scene template used to create swatch template.
@export var swatch_template: PackedScene


## When the node is ready, this function sets [code]background_opacity_slider.value[/code] to
## [code]SM_Globals.user_prefs.background_alpha[/code].
func _ready():
    set_normal_colors()
    set_dark_colors()
    background_opacity_slider.value = SM_Globals.user_prefs.background_alpha
    add_normal_pallets()
    add_dark_pallets()

    VNSignalBus.listen_for(ui_updated, VNSignalBus._on_ui_update)


## Sets the normal-palette controls to the values stored in user preferences.
func set_normal_colors():
    normal_accent_color_picker.color = Color.from_string(SM_Globals.user_prefs.normal_base_color, Color.GREEN)
    normal_text_color_picker.color = Color.from_string(SM_Globals.user_prefs.normal_text_color, Color.WHITE)
    normal_outline_color_picker.color = Color.from_string(SM_Globals.user_prefs.normal_outline_color, Color.BLACK)


## Sets the dark-palette controls to the values stored in user preferences.
func set_dark_colors():
    dark_accent_color_picker.color = Color.from_string(SM_Globals.user_prefs.dark_base_color, Color.PURPLE)
    dark_text_color_picker.color = Color.from_string(SM_Globals.user_prefs.dark_text_color, Color.WHITE)
    dark_outline_color_picker.color = Color.from_string(SM_Globals.user_prefs.dark_outline_color, Color.BLACK)


## Creates preset swatches for the normal accent, text and outline colors.
func add_normal_pallets():
    add_pallet_to_container(
        normal_accent_preset_container, swatch_template, ColorCodes.NORMAL, on_normal_accent_changed
    )
    add_pallet_to_container(normal_text_preset_container, swatch_template, ColorCodes.NORMAL, on_normal_text_changed)
    add_pallet_to_container(
        normal_outline_preset_container, swatch_template, ColorCodes.NORMAL, on_normal_outline_changed
    )


## Creates preset swatches for the dark accent, text and outline colors.
func add_dark_pallets():
    add_pallet_to_container(dark_accent_preset_container, swatch_template, ColorCodes.DARK, on_dark_accent_changed)
    add_pallet_to_container(dark_text_preset_container, swatch_template, ColorCodes.DARK, on_dark_text_changed)
    add_pallet_to_container(dark_outline_preset_container, swatch_template, ColorCodes.DARK, on_dark_outline_changed)


## Creates color-swatch buttons in the supplied container and connects them to the supplied
## selection handler.
func add_pallet_to_container(
    container: HBoxContainer, template: PackedScene, color_codes: Dictionary, listen_function: Callable
) -> void:
    for codename in color_codes:
        var new_swatch = template.instantiate()
        new_swatch.on_create(color_codes[codename])
        container.add_child(new_swatch)
        new_swatch.color_changed.connect(listen_function)


## Applies the selected normal accent to user preferences and refreshes the interface colors.
func on_normal_accent_changed(color: String) -> void:
    normal_accent_color_picker.color = Color.from_string(color, Color.GREEN)
    SM_Globals.user_prefs.normal_base_color = color
    ui_updated.emit()


## Applies the selected normal text to user preferences and refreshes the interface colors.
func on_normal_text_changed(color: String) -> void:
    normal_text_color_picker.color = Color.from_string(color, Color.WHITE)
    SM_Globals.user_prefs.normal_text_color = color
    ui_updated.emit()


## Applies the selected normal outline to user preferences and refreshes the interface colors.
func on_normal_outline_changed(color: String) -> void:
    normal_outline_color_picker.color = Color.from_string(color, Color.BLACK)
    SM_Globals.user_prefs.normal_outline_color = color
    ui_updated.emit()


## Applies the selected dark accent to user preferences and refreshes the interface colors.
func on_dark_accent_changed(color: String) -> void:
    dark_accent_color_picker.color = Color.from_string(color, Color.PURPLE)
    SM_Globals.user_prefs.dark_base_color = color
    ui_updated.emit()


## Applies the selected dark text to user preferences and refreshes the interface colors.
func on_dark_text_changed(color: String) -> void:
    dark_text_color_picker.color = Color.from_string(color, Color.WHITE)
    SM_Globals.user_prefs.dark_outline_color = color
    ui_updated.emit()


## Applies the selected dark outline to user preferences and refreshes the interface colors.
func on_dark_outline_changed(color: String) -> void:
    dark_outline_color_picker.color = Color.from_string(color, Color.BLACK)
    SM_Globals.user_prefs.dark_outline_color = color
    ui_updated.emit()


## Applies the selected normal accent picker color to user preferences and refreshes the interface
## colors.
func _on_normal_accent_picker_color_changed(color: Color) -> void:
    SM_Globals.user_prefs.normal_base_color = color.to_html()
    ui_updated.emit()


## Applies the selected normal text picker color to user preferences and refreshes the interface
## colors.
func _on_normal_text_picker_color_changed(color: Color) -> void:
    SM_Globals.user_prefs.normal_text_color = color.to_html()
    ui_updated.emit()


## Applies the selected normal outline picker color to user preferences and refreshes the interface
## colors.
func _on_normal_outline_picker_color_changed(color: Color) -> void:
    SM_Globals.user_prefs.normal_outline_color = color.to_html()
    ui_updated.emit()


## Applies the selected dark accent picker color to user preferences and refreshes the interface
## colors.
func _on_dark_accent_picker_color_changed(color: Color) -> void:
    SM_Globals.user_prefs.dark_base_color = color.to_html()
    ui_updated.emit()


## Applies the selected dark text picker color to user preferences and refreshes the interface
## colors.
func _on_dark_text_picker_color_changed(color: Color) -> void:
    SM_Globals.user_prefs.dark_text_color = color.to_html()
    ui_updated.emit()


## Applies the selected dark outline picker color to user preferences and refreshes the interface
## colors.
func _on_dark_outline_picker_color_changed(color: Color) -> void:
    SM_Globals.user_prefs.dark_outline_color = color.to_html()
    ui_updated.emit()


## Applies the selected background opacity slider to user preferences and refreshes the interface
## colors.
func _on_background_opacity_slider_drag_ended(value_changed) -> void:
    if not value_changed:
        return

    SM_Globals.user_prefs.background_alpha = background_opacity_slider.value
    ui_updated.emit()
