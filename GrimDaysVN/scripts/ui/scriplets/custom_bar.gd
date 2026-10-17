extends ProgressBar
## Updates a custom progress display as its value changes.
class_name CustomProgressBar

## Scene object used for label.
@export var label: Label
## Scene object used for frame.
@export var frame: Panel
## Whether recolor is currently enabled or true.
@export var recolor: bool = true


## When the node is ready, this function connects responses to
## [code]VNSignalBus.on_ui_update[/code]; sets [code]self_modulate.a[/code] to
## [code]Basics.OPAQUE[/code].
func _ready():
    if recolor:
        SystemHelpers.color_self(self, frame)
        self_modulate.a = Basics.OPAQUE
        VNSignalBus.on_ui_update.connect(color_self)


## Applies the selected UI color scheme to this control's background and frame.
func color_self():
    SystemHelpers.color_self(self, frame)
    self_modulate.a = Basics.OPAQUE


## Connects the supplied notification to its response function, using the connection checks in this
## helper.
func listen_for(signal_sent, on_signal):
    if signal_sent.is_connected(on_signal):
        signal_sent.disconnect(on_signal)

    signal_sent.connect(on_signal)


## Smoothly changes [code]value[/code], [code]text[/code] over time.
func on_value_change(value_sent):
    var floored_value = floorf(value_sent) if value_sent > 1 else snappedf(value_sent, 0.01)
    var tween = create_tween().set_ignore_time_scale(true).set_parallel()
    tween.tween_property(self, "value", floored_value, VNAnimationTimes.STANDARD)
    tween.tween_property(label, "text", str(int(floored_value)) + "%", VNAnimationTimes.STANDARD)
