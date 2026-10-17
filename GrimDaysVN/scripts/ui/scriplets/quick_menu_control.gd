extends MarginContainer
## Animation player used for player.
@export var player: AnimationPlayer

## Notification for show history.
signal show_history

## Whether showing is currently enabled or true.
var showing: bool = false


## Connects history requests from this menu to the shared history handler.
func _ready() -> void:
    VNSignalBus.listen_for(show_history, VNSignalBus.on_show_history)


## Starts playback on [code]player[/code].
func _on_quick_menu_toggle_toggled(toggled_on: bool) -> void:
    if not toggled_on:
        player.play_backwards("quick_menu_enter")
    else:
        player.play("quick_menu_enter")


## Currently performs no work; this function is a placeholder for behavior supplied later or by a
## child script.
func _on_back_button_up() -> void:
    pass  # Replace with function body.


## Sets [code]Dialogic.Inputs.auto_advance.enabled_until_user_input[/code] to
## [code]toggled_on[/code].
func _on_auto_button_up(toggled_on: bool) -> void:
    Dialogic.Inputs.auto_advance.enabled_until_user_input = toggled_on


## Sets [code]auto_skip.enabled[/code] to [code]toggled_on[/code].
func _on_skip_toggled(toggled_on: bool) -> void:
    var auto_skip: DialogicAutoSkip = Dialogic.Inputs.auto_skip
    auto_skip.enabled = toggled_on


## Sends [code]show_history[/code] notifications.
func _on_log_button_up() -> void:
    show_history.emit()


## Currently performs no work; this function is a placeholder for behavior supplied later or by a
## child script.
func _on_phone_button_up() -> void:
    pass  # Replace with function body.


## Opens the settings menu through the UI director.
func _on_settings_button_up() -> void:
    UIDirector.show_settings_menu()


## Currently performs no work; this function is a placeholder for behavior supplied later or by a
## child script.
func _on_quick_save_pressed() -> void:
    pass  # Replace with function body.


## Currently performs no work; this function is a placeholder for behavior supplied later or by a
## child script.
func _on_quick_load_button_up() -> void:
    pass  # Replace with function body.
