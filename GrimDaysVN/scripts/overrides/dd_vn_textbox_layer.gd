# Editor configuration for dd_vn_textbox_layer.
@tool
extends DialogicLayoutLayer
## This layer's scene file contains following nodes:
## - a dialog_text node
## - a name_label node
## - a next_indicator node
## - a type_sound node
##
## As well as custom:
## - animations
## - auto-advance progress indicator
##
## If you want to customize this layer, here is a little rundown of this layer:
## The Layer Settings are divided into the `@export_group`s below.
## They get applied in [method _apply_export_overrides].
## Each `@export_group` has its own method to apply the settings to the scene.
## If you want to change a specific part inside the scene, you can simply
## remove or add # (commenting) to the method line.
enum Alignments { LEFT, CENTER, RIGHT }

## Named choices for animations in: [code]NONE[/code], [code]POP_IN[/code], [code]FADE_UP[/code].
enum AnimationsIn { NONE, POP_IN, FADE_UP }
## Named choices for animations out: [code]NONE[/code], [code]POP_OUT[/code],
## [code]FADE_DOWN[/code].
enum AnimationsOut { NONE, POP_OUT, FADE_DOWN }
## Named choices for animations new text: [code]NONE[/code], [code]WIGGLE[/code].
enum AnimationsNewText { NONE, WIGGLE }

const NEXT_INDICATOR_BLINK = DialogicNode_NextIndicator.Animations.BLINK

@export_group("Text")

## Horizontal alignment of dialogue text inside the box.
@export_subgroup("Alignment & Size")
@export var text_alignment: Alignments = Alignments.LEFT

## Animation used when the dialogue box appears.
@export_subgroup("Animation")
@export var box_animation_in: AnimationsIn = AnimationsIn.FADE_UP
## Animation used when the dialogue box disappears.
@export var box_animation_out: AnimationsOut = AnimationsOut.FADE_DOWN
## Animation used when the dialogue box receives new text.
@export var box_animation_new_text: AnimationsNewText = AnimationsNewText.NONE

## Whether next indicator enabled is currently enabled or true.
@export_group("Indicators")
@export_subgroup("Next Indicator")
@export var next_indicator_enabled: bool = true
## Whether next indicator show on questions is currently enabled or true.
@export var next_indicator_show_on_questions: bool = true
## Whether next indicator show on autoadvance is currently enabled or true.
@export var next_indicator_show_on_autoadvance: bool = false
## Animation used by the indicator inviting the player to advance dialogue.
@export var next_indicator_animation: DialogicNode_NextIndicator.Animations = NEXT_INDICATOR_BLINK
## File path for next indicator.
@export_file("*.png", "*.svg", "*.tres") var next_indicator_texture: String = ""
## Coordinates used for next indicator size.
@export var next_indicator_size: Vector2 = Vector2(25, 25)

## Whether autoadvance progressbar is currently enabled or true.
@export_subgroup("Autoadvance")
@export var autoadvance_progressbar: bool = true


## Applies the exported textbox and advance-indicator choices to their scene controls.
func _apply_export_overrides() -> void:
    if !is_inside_tree():
        await ready

    if not VNSignalBus.on_ui_update.is_connected(_apply_export_overrides):
        VNSignalBus.on_ui_update.connect(_apply_export_overrides)

    ## FONT SETTINGS
    _apply_text_settings()

    ## BOX SETTINGS
    _apply_box_settings()

    #_apply_side_settings()

    ## BOX ANIMATIONS
    _apply_box_animations_settings()

    ## NAME LABEL SETTINGS
    _apply_name_label_settings()

    ## NEXT INDICATOR SETTINGS
    _apply_indicator_settings()

    ## OTHER
    var progress_bar: ProgressBar = %AutoAdvanceProgressbar
    progress_bar.set(&"enabled", autoadvance_progressbar)

    #### SOUNDS


## Applies all text box settings to the scene.
## Except the box animations.
func _apply_box_settings() -> void:
    var dialog_text_panel: PanelContainer = %DialogTextPanel
    var dialog_text_frame: Panel = %DialogicTextFrrame

    #SystemHelpers.color_self(dialog_text_panel, dialog_text_frame)


## Applies the selected color scheme to the side-panel background and frames.
func _apply_side_settings() -> void:
    var side_background: Panel = %"Side Panel BG"
    var side_background_frame: Panel = %"Side Panel BG Frame"
    var side_frame: Panel = %"Side Panel Front Frame"

    SystemHelpers.color_self(side_background, side_background_frame)
    SystemHelpers.color_self(side_background, side_frame)


## Applies box animations settings to the scene.
func _apply_box_animations_settings() -> void:
    var animations: AnimationPlayer = %Animations
    animations.set(&"animation_in", box_animation_in)
    animations.set(&"animation_out", box_animation_out)
    animations.set(&"animation_new_text", box_animation_new_text)


## Applies all name label settings to the scene.
func _apply_name_label_settings() -> void:
    var name_label_panel: PanelContainer = %NameLabelPanel
    var name_label_frame: Panel = %NameLabelFrame

    #SystemHelpers.color_self(name_label_panel, name_label_frame)


## Applies all text settings to the scene.
func _apply_text_settings() -> void:
    var dialog_text: DialogicNode_DialogText = %DialogicNode_DialogText
    dialog_text.alignment = text_alignment as DialogicNode_DialogText.Alignment

    var rich_text_label = dialog_text as RichTextLabel
    rich_text_label.add_theme_color_override(&"default_color", SystemHelpers.current_text_color())
    rich_text_label.add_theme_color_override(
        &"font_shadow_color", SystemHelpers.current_outline_color())
    rich_text_label.add_theme_color_override(
        &"font_outline_color", SystemHelpers.current_outline_color())


## Applies all indicator settings to the scene.
func _apply_indicator_settings() -> void:
    var next_indicator: DialogicNode_NextIndicator = %NextIndicator
    next_indicator.enabled = next_indicator_enabled

    if next_indicator_enabled:
        next_indicator.animation = next_indicator_animation
        if ResourceLoader.exists(next_indicator_texture):
            next_indicator.texture = load(next_indicator_texture)
        next_indicator.show_on_questions = next_indicator_show_on_questions
        next_indicator.show_on_autoadvance = next_indicator_show_on_autoadvance
        next_indicator.texture_size = next_indicator_size
