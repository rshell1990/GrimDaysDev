extends Range

## Whether enabled is currently enabled or true.
var enabled: bool = true


## Shows the current auto-advance progress, hiding the indicator when disabled or when Dialogic
## reports no progress.
func _process(_delta: float) -> void:
    if !enabled:
        hide()
        return
    if DialogicUtil.autoload().Inputs.auto_advance.get_progress() < 0:
        hide()
    else:
        show()
        value = DialogicUtil.autoload().Inputs.auto_advance.get_progress()
