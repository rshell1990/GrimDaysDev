extends GameManagerState
## Game-mode script for navigation. Overrides the base state where this mode needs its own behavior.
class_name NavigationState


## Runs the parent script’s version of this function with the supplied arguments.
func _ready() -> void:
    super()


## Runs the parent script’s version of this function with the supplied arguments.
func _process(_delta: float) -> void:
    super(_delta)


## Runs the parent script’s version of this function with the supplied arguments.
func _input(_event: InputEvent) -> void:
    super(_event)


## Sets [code]Engine.time_scale[/code] to [code]1.0[/code]; sets
## [code]GameManager.current_event[/code] to null; sends [code]VNSignalBus.clear_rollback[/code]
## notifications. It pauses for [code]UIDirector.fade_flag_operator.screen_shot_faded[/code],
## [code]SceneManager.load_complete[/code] before continuing.
func on_start() -> void:
    super()
    var token := parent.revision
    Engine.time_scale = 1.0
    Dialogic.Inputs.auto_skip.enabled = false
    GameManager.current_event = null
    if UIDirector.fade_flag_operator.modulate.a > 0.0 and not SaveAndLoadSystemManager.restoring_data:
        await UIDirector.fade_flag_operator.screen_shot_faded
        if not parent.owns_state(id, token):
            return
    if SystemAdministrators.current_location() == &"PrimeMap":
        SceneManager.swap_scenes(
            self,
            SceneManager.get_tree().current_scene,
            Repositories.get_resource_path(RepositoryTypes.SCENES, "prime_map")
        )
    elif get_tree().current_scene is not MapOperator:
        SceneManager.swap_scenes(
            self,
            SceneManager.get_tree().current_scene,
            Repositories.get_resource_path(RepositoryTypes.SCENES, "navigation_location")
        )
    if SceneManager.swapping:
        await SceneManager.load_complete
        if not parent.owns_state(id, token):
            return
    UIDirector.show_navigation()
    if not SaveAndLoadSystemManager.restoring_data:
        VNSignalBus.clear_rollback.emit()


## Sends [code]VNSignalBus.on_tooltip_hide[/code] notifications.
func on_end() -> void:
    super()
    VNSignalBus.on_tooltip_hide.emit()
    UIDirector.hide_navigation()
