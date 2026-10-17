extends CanvasLayer

## Scene node used for color rect, found when this node is ready.
@onready var color_rect: ColorRect = get_child(0)


## Sets [code]color_rect.mouse_filter[/code] to [code]Control.MOUSE_FILTER_IGNORE[/code].
func fade(direction: Basics.FADE):
    if direction == Basics.FADE.IN:
        tween_to(Basics.OPAQUE)
        color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    elif direction == Basics.FADE.OUT:
        tween_to(Basics.TRANSPARENT)
        color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Smoothly changes opacity over time. It pauses for [code]tween.tween_property(color_rect,
## "modulate:a", new_alpha, VNAnimationTimes.FAST).finished[/code] before continuing.
func tween_to(new_alpha: float):
    var tween = create_tween()
    await tween.tween_property(color_rect, "modulate:a", new_alpha, VNAnimationTimes.FAST).finished
