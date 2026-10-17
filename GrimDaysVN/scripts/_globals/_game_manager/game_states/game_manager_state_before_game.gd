extends GameManagerState
## Game-mode script for before game. Overrides the base state where this mode needs its own
## behavior.
class_name BeforeGameState


## Runs the parent script’s version of this function with the supplied arguments.
func _ready() -> void:
    super()


## Runs the parent script’s version of this function with the supplied arguments.
func _process(_delta: float) -> void:
    super(_delta)


## Runs the parent script’s version of this function with the supplied arguments.
func _input(_event: InputEvent) -> void:
    super(_event)


## Sends [code]VNSignalBus.reset_sub_systems[/code] notifications. It pauses for
## [code]SystemAdministrators.ready[/code] before continuing.
func on_start() -> void:
    super()
    var token := parent.revision
    if not SystemAdministrators.is_node_ready():
        await SystemAdministrators.ready
        if not parent.owns_state(id, token):
            return
    SoundManager.stop_all()
    VNSignalBus.reset_sub_systems.emit()
