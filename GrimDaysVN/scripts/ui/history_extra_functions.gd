extends Node


## When the node is ready, this function connects responses to
## [code]VNSignalBus.show_history[/code], [code]HistoryBox.hidden[/code].
func _ready() -> void:
    VNSignalBus.show_history.connect(on_show_history)
    %HistoryBox.hidden.connect(on_history_hidden)


## Opens dialogue history through the parent control and shows its panel and cover.
func on_show_history() -> void:
    $".."._on_show_history_pressed()
    %Panel.visible = true
    %Cover.visible = true


## Hides the history panel and its screen cover.
func on_history_hidden() -> void:
    %Cover.visible = false
    %Panel.visible = false
