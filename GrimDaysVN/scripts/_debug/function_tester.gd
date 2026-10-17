extends Control


## When the node is ready, this function connects responses to
## [code]Dialogic.timeline_started[/code], [code]Dialogic.timeline_ended[/code].
func _ready() -> void:
    Dialogic.timeline_started.connect(on_timeline_start)
    Dialogic.timeline_ended.connect(on_timeline_end)


## Advances the game clock through [code]SystemHeadquarters.known_administrators.Time[/code].
func _on_quit_button_up() -> void:
    SystemHeadquarters.known_administrators.Time.advance_time()


## Hides this test control and disables its processing while dialogue is running.
func on_timeline_start() -> void:
    process_mode = PROCESS_MODE_DISABLED
    visible = false


## Shows this test control and restores inherited processing after dialogue ends.
func on_timeline_end() -> void:
    process_mode = PROCESS_MODE_INHERIT
    visible = true
