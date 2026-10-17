# Editor configuration for DDTextInputEvent.
@tool
extends DialogicTextInputEvent
## Custom dialogue event that opens the project's text-input prompt.
class_name DDTextInputEvent

## Who called this.
var caller: Variant = null
## Text-input event helper created for the custom dialogue input operation.
var input: DDTextInput = DDTextInput.new()


## Connects responses to [code]dialogic.TextInput.input_confirmed[/code]; sets
## [code]dialogic.Inputs.auto_skip.enabled[/code] to false; sets [code]dialogic.current_state[/code]
## to [code]DialogicGameHandler.States.WAITING[/code].
func _execute() -> void:
    dialogic.Inputs.auto_skip.enabled = false
    dialogic.current_state = DialogicGameHandler.States.WAITING
    input.show_input(text, caller, default, placeholder, allow_empty)
    dialogic.TextInput.input_confirmed.connect(
        _on_DialogicTextInput_input_confirmed, CONNECT_ONE_SHOT
    )
