extends Node
## Timer providing the delay before a tooltip appears.
@export var show_timer: Timer
## Lookup ID used to find this tooltip text.
@export var tooltip_id: String
## Whether showing is currently enabled or true.
var showing: bool = false

## Notification for show tooltip. Supplies [code]header_text[/code], [code]description_text[/code]
## to connected functions.
signal show_tooltip(header_text, description_text)


## When the node is ready, this function connects responses to [code]show_timer.timeout[/code].
func _ready() -> void:
    VNSignalBus.listen_for(show_tooltip, VNSignalBus.on_tooltip_show)
    show_timer.timeout.connect(on_show_timer_timeout)


## Starts the delay timer before showing the tooltip.
func execute() -> void:
    show_timer.start()


## Sets [code]showing[/code] to true; sends [code]show_tooltip[/code] notifications.
func on_show_timer_timeout() -> void:
    if showing:
        return
    var tooltip = Repositories.get_info(RepositoryTypes.TOOLTIPS, tooltip_id)
    show_tooltip.emit(tooltip.header, tooltip.description)
    showing = true
