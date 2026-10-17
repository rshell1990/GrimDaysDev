extends LoadableCanvasLayer
class_name TooltipOperator

## Shared fixed value for padding.
const PADDING: float = 30.0

## Scene object used for background.
@export var background: PanelContainer
## Scene object used for frame.
@export var frame: PanelContainer
## Scene object used for header.
@export var header: Label
## Scene object used for description.
@export var description: Label


## When the node is ready, this function connects responses to
## [code]VNSignalBus.on_tooltip_hide[/code], [code]VNSignalBus.on_tooltip_show[/code].
func _ready():
    VNSignalBus.on_tooltip_hide.connect(on_tooltip_hide)
    VNSignalBus.on_tooltip_show.connect(on_tooltip_show)
    VNSignalBus.on_ui_update.connect(color_ui)

    color_ui()


## Hides the currently displayed tooltip.
func on_tooltip_hide():
    if background.modulate.a > 0.99:
        var tween = create_tween().set_ignore_time_scale(true)
        tween.tween_property(background, "modulate:a", 0.0, VNAnimationTimes.FAST)
    else:
        background.modulate.a = 0.0

    visible = false


## Sizes and positions the tooltip using its displayed scale, clamped inside the screen padding.
func on_tooltip_show(header_text: Variant, description_text: Variant, position = null) -> void:
    visible = true
    header.text = header_text if header_text else "MISSING Header!"
    description.text = description_text if description_text else "MISSING Description!"
    background.reset_size()
    var display_size := background.size * background.scale.abs()
    var target := get_viewport().get_mouse_position() - Vector2(display_size.x * 0.5, display_size.y)
    var limit := Vector2(Defaults.INTERNAL_WIDTH, Defaults.INTERNAL_HEIGHT) - display_size - Vector2.ONE * PADDING
    background.global_position = target.clamp(Vector2.ONE * PADDING, limit.max(Vector2.ONE * PADDING))
    if position != null:
        background.position = position
    var tween = create_tween().set_ignore_time_scale(true)
    tween.tween_property(background, "modulate:a", 1.0, VNAnimationTimes.FAST)


## Applies the selected UI color scheme to the tooltip's background and frame.
func color_ui():
    SystemHelpers.color_self(background, frame)
