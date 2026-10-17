extends Node
## Base behavior for one game mode. Enables its processing only while that mode is active.
class_name GameManagerState

## Game-mode choice represented by this state node; compared with the manager’s active mode.
@export var id: GameManagerStates.STATES

## Parent game-state manager used by this node.
var parent: GameManagerStates


## When the node is ready, this function connects responses to
## [code]grandparent.state_changed[/code]; sets [code]parent[/code] to [code]get_parent()[/code].
func _ready() -> void:
    parent = get_parent()
    var grandparent = parent.get_parent()
    grandparent.state_changed.connect(on_state_change)


## Currently performs no work; this function is a placeholder for behavior supplied later or by a
## child script.
func _process(_delta: float) -> void:
    pass


## Currently performs no work; this function is a placeholder for behavior supplied later or by a
## child script.
func _input(_event: InputEvent) -> void:
    pass


## Returns true when this state has no manager or is not the current state. An inactive state also
## disables its own processing.
func _guard_clause():
    if parent == null:
        CustomLogger.warn(self, _guard_clause, " does not have a parent.", CustomLogger.LEVEL.MILD)
        return true

    if parent.current_state.id != id:
        CustomLogger.hint(
            self, self._guard_clause, " is being disabled due to not being the active state.", CustomLogger.LEVEL.MILD
        )
        process_mode = PROCESS_MODE_DISABLED
        return true

    return false


## Enables this state only when the manager identifies it as the current game mode.
func on_state_change(_new_state: GameManagerStates.STATES) -> void:
    if !_guard_clause():
        CustomLogger.hint(
            self, self.on_state_change, "is being enabled after becoming the active state.", CustomLogger.LEVEL.MILD
        )
        process_mode = PROCESS_MODE_INHERIT


## Logs that this game mode is starting. Child scripts can extend this with their own startup
## behavior.
func on_start() -> void:
    CustomLogger.hint(self, self.on_start, "[color=#0FF]is starting.[/color]", CustomLogger.LEVEL.MILD)


## Logs that this game mode is ending. Child scripts can extend this with their own ending behavior.
func on_end() -> void:
    CustomLogger.hint(self, self.on_start, "[color=#F50]is ending.[/color]", CustomLogger.LEVEL.MILD)
