extends Control
## Scene control for timer, used to display or change the related setting.
@export var timer: Timer
## Lookup ID used to find this tooltip text.
@export var tooltip_id: String
## Scene object used for triggered by.
@export var triggered_by: Control
## Scene object used for tooltip info holder.
@export var tooltip_info_holder: Control
## Notification for show tooltip. Supplies [code]header_text[/code], [code]description_text[/code]
## to connected functions.
signal show_tooltip(header_text, description_text)
## Notification for hide tooltip.
signal hide_tooltip
## Shared fixed value for timer duration.
const TIMER_DURATION: float = 0.2
## Whether showing is currently enabled or true.
var showing: bool = false


## When the node is ready, this function connects responses to
## [code]triggered_by.mouse_entered[/code], [code]triggered_by.mouse_exited[/code],
## [code]timer.timeout[/code].
func _ready():
    if not triggered_by:
        CustomLogger.warn(self, _ready, "Missing triggering object for tooltip...", CustomLogger.LEVEL.MILD)
        return
    triggered_by.mouse_entered.connect(on_mouse_entered)
    triggered_by.mouse_exited.connect(on_mouse_exited)
    timer.timeout.connect(on_timeout)
    VNSignalBus.listen_for(show_tooltip, VNSignalBus._on_tooltip_show)
    VNSignalBus.listen_for(hide_tooltip, VNSignalBus._on_tooltip_hide)


## Starts the tooltip delay timer unless this tooltip is already showing.
func on_mouse_entered():
    if showing:
        return
    timer.start()


## Stops [code]timer[/code]; sets [code]timer.wait_time[/code] to [code]TIMER_DURATION[/code]; sets
## [code]showing[/code] to false. It also sends [code]hide_tooltip[/code] notifications.
func on_mouse_exited():
    timer.stop()
    timer.wait_time = TIMER_DURATION
    hide_tooltip.emit()
    showing = false


## Sets [code]showing[/code] to true; sets [code]tooltip_info_holder[/code] to [code]parent[/code];
## sends [code]show_tooltip[/code] notifications.
func on_timeout():
    if showing:
        return
    showing = true
    var tooltip = {"header": "", "description": ""}
    if tooltip_id != "":
        tooltip = Repositories.get_info(RepositoryTypes.TOOLTIPS, tooltip_id)
        show_tooltip.emit(tooltip.header, tooltip.description)
    else:
        if tooltip_info_holder == null:
            var parent: Control = get_parent()
            if parent == null:
                return
            tooltip_info_holder = parent

        if tooltip_info_holder.has_method("get_custom_tooltip"):
            tooltip = tooltip_info_holder.get_custom_tooltip()

        if tooltip.header != "":
            show_tooltip.emit(tooltip.header, tooltip.description)
