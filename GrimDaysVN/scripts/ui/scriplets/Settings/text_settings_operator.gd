extends Node
class_name TextSettingsOperator

## Shared fixed value for default text speed.
const DEFAULT_TEXT_SPEED: float = 0.1
## Shared fixed value for default auto delay.
const DEFAULT_AUTO_DELAY: float = 1.0
## Shared fixed value for default auto additional delay.
const DEFAULT_AUTO_ADDITIONAL_DELAY: float = 0.1

## Notification for primary font changed. Supplies [code]new_font[/code] to connected functions.
signal primary_font_changed(new_font: String)
## Notification for secondary font changed. Supplies [code]new_font[/code] to connected functions.
signal secondary_font_changed(new_font: String)
## Notification for tertiary font changed. Supplies [code]new_font[/code] to connected functions.
signal tertiary_font_changed(new_font: String)
## Notification for font scale changed. Supplies [code]new_scale[/code] to connected functions.
signal font_scale_changed(new_scale: float)

## Collection of fonts offered by the text settings menu.
@export var fonts_resource: GameFonts
## Scene control for primary dropdown, used to display or change the related setting.
@export var primary_dropdown: OptionButton
## Scene control for secondary dropdown, used to display or change the related setting.
@export var secondary_dropdown: OptionButton
## Scene control for tertiary dropdown, used to display or change the related setting.
@export var tertiary_dropdown: OptionButton
## Scene control for font scale slider, used to display or change the related setting.
@export var font_scale_slider: Slider
## Scene control for display speed slider, used to display or change the related setting.
@export var display_speed_slider: Slider
## Scene control for auto mode speed slider, used to display or change the related setting.
@export var auto_mode_speed_slider: Slider
## Scene control for skip unread option, used to display or change the related setting.
@export var skip_unread_option: CheckButton

## User preference resource containing the chosen display, audio and text settings.
var user_prefs: UserPrefs


## When the node is ready, this function sets [code]user_prefs[/code] to
## [code]SM_Globals.user_prefs[/code]; sets [code]display_speed_slider.value[/code] to
## [code]user_prefs.text_speed[/code]; sets [code]auto_mode_speed_slider.value[/code] to
## [code]user_prefs.auto_speed[/code].
func _ready() -> void:
    user_prefs = SM_Globals.user_prefs
    connect_to_signals()
    connect_signals()
    create_font_selection()
    select_fonts()
    display_speed_slider.value = user_prefs.text_speed
    auto_mode_speed_slider.value = user_prefs.auto_speed
    skip_unread_option.button_pressed = user_prefs.skip_unread


## Connects responses to [code]primary_dropdown.item_selected[/code],
## [code]secondary_dropdown.item_selected[/code], [code]tertiary_dropdown.item_selected[/code],
## [code]font_scale_slider.value_changed[/code].
func connect_to_signals() -> void:
    primary_dropdown.item_selected.connect(primary_font_selected)
    secondary_dropdown.item_selected.connect(secondary_font_selected)
    tertiary_dropdown.item_selected.connect(tertiary_font_selected)
    font_scale_slider.value_changed.connect(font_scale_adjusted)
    display_speed_slider.value_changed.connect(display_speed_adjusted)
    auto_mode_speed_slider.value_changed.connect(auto_speed_adjusted)
    skip_unread_option.toggled.connect(on_skip_unread_toggled)


## Connects font and scale changes to the shared notifications used by text controls.
func connect_signals() -> void:
    VNSignalBus.listen_for(primary_font_changed, VNSignalBus._on_primary_font_changed)
    VNSignalBus.listen_for(secondary_font_changed, VNSignalBus._on_secondary_font_changed)
    VNSignalBus.listen_for(tertiary_font_changed, VNSignalBus._on_tertiary_font_changed)
    VNSignalBus.listen_for(font_scale_changed, VNSignalBus._on_font_scale_changed)


## Fills all three font dropdowns with readable names from the configured font collection.
func create_font_selection() -> void:
    for font in fonts_resource.all:
        primary_dropdown.add_item(font.id.capitalize())
        secondary_dropdown.add_item(font.id.capitalize())
        tertiary_dropdown.add_item(font.id.capitalize())


## Selects the saved primary, secondary and tertiary fonts in their dropdowns.
func select_fonts() -> void:
    primary_dropdown.select(user_prefs.primary_font)
    secondary_dropdown.select(user_prefs.secondary_font)
    tertiary_dropdown.select(user_prefs.tertiary_font)

    primary_font_selected(primary_dropdown.selected)
    secondary_font_selected(secondary_dropdown.selected)
    tertiary_font_selected(tertiary_dropdown.selected)

    font_scale_slider.value = user_prefs.font_scale


## Updates the dialogue text-display speed from the settings control.
func display_speed_adjusted(new_speed: float) -> void:
    Dialogic.Text.update_text_speed(DEFAULT_TEXT_SPEED, false, new_speed)
    var text_label = display_speed_slider.get_child(0)
    var new_text = str(DEFAULT_TEXT_SPEED * new_speed) + " second(s) (" + str(100 * new_speed) + "%)"
    text_label.text = new_text
    user_prefs.text_speed = new_speed
    user_prefs.save()


## Updates the dialogue auto-advance speed from the settings control.
func auto_speed_adjusted(new_speed: float) -> void:
    Dialogic.Inputs.auto_advance.fixed_delay = DEFAULT_AUTO_DELAY * new_speed
    Dialogic.Inputs.auto_advance.per_character_delay = DEFAULT_AUTO_ADDITIONAL_DELAY * new_speed
    var text_label = auto_mode_speed_slider.get_child(0)
    var new_text = (
        str(DEFAULT_AUTO_DELAY * new_speed)
        + " second(s) "
        + str(DEFAULT_AUTO_ADDITIONAL_DELAY * new_speed)
        + " second(s) per character ("
        + str(100 * new_speed)
        + "%)"
    )
    text_label.text = new_text
    user_prefs.auto_speed = new_speed
    user_prefs.save()


## Stores the selected font scale and notifies text controls to update.
func font_scale_adjusted(new_scale: float) -> void:
    font_scale_changed.emit(new_scale)
    user_prefs.font_scale = new_scale
    user_prefs.save()


## Stores the primary font choice and announces the change.
func primary_font_selected(selection: int) -> void:
    primary_font_changed.emit(fonts_resource.all[selection].id)
    user_prefs.primary_font = selection
    user_prefs.save()


## Stores the secondary font choice and announces the change.
func secondary_font_selected(selection: int) -> void:
    secondary_font_changed.emit(fonts_resource.all[selection].id)
    user_prefs.secondary_font = selection
    user_prefs.save()


## Stores the tertiary font choice and announces the change.
func tertiary_font_selected(selection: int) -> void:
    tertiary_font_changed.emit(fonts_resource.all[selection].id)
    user_prefs.tertiary_font = selection
    user_prefs.save()


## Updates whether dialogue skipping may pass unread text.
func on_skip_unread_toggled(toggled: bool) -> void:
    user_prefs.skip_unread = toggled
    user_prefs.save()
