extends DialogicNode_Input
## Shared fixed value for input delay.
const INPUT_DELAY: float = 0.25
## Notification for rollback initiated.
signal rollback_initiated

## Whether rollback locked is currently enabled or true.
var _rollback_locked: bool = false
## Pattern used to build a rollback save-slot name from its prefix and number.
var slot_name_to_format: String = "{prefix}___rollback-save___{number}"
## Name identifying the save slot this operation uses.
var slot_name: String
## Number identifying the rollback checkpoint to restore.
var to_load: int
## Time used to space input responses so repeated input does not trigger too quickly.
var last_input: float = INPUT_DELAY
#endregion


#region PREPARE
## Checks the prior checkpoint and permits rollback only into Scenario state.
## Missing manager data and other saved modes are rejected.
func _check_if_can_rollback() -> bool:
    if UIDirector.rollback_indicator.visible:
        UIDirector.add_system_message("Previous rollback still processing.")
        CustomLogger.hint(
            self, self._check_if_can_rollback, "Rollback locked.", CustomLogger.LEVEL.MILD
        )
        return false

    if Dialogic.paused:
        CustomLogger.hint(
            self, self._check_if_can_rollback, "Dialogic paused currently.", CustomLogger.LEVEL.MILD
        )
        return false

    to_load = Dialogic.VAR.lines_read - 1

    if to_load < 0:
        Dialogic.paused = false
        return false

    slot_name = slot_name_to_format.format(
        {"prefix": Dialogic.VAR.prefix, "number": to_load % SystemLimits.CHECKPOINTS}
    )
    CustomLogger.hint(
        self,
        self._check_if_can_rollback,
        slot_name + "will be selected for rollback.",
        CustomLogger.LEVEL.MILD
    )

    if not Dialogic.Save.has_slot(slot_name):
        CustomLogger.warn(
            self,
            self._check_if_can_rollback,
            slot_name + "[color=#F00][u] does not exist.[/u][/color]",
            CustomLogger.LEVEL.MILD
        )
        return false
    var rollback_states: Array = [
        GameManagerStates.STATES.Scenario,
        GameManagerStates.STATES.ScenarioSequence,
    ]
    if GameManager.state not in rollback_states:
        UIDirector.add_system_message("Rollback is unavailable at this time.")
        CustomLogger.hint(
            self,
            self._check_if_can_rollback,
            "[color=#FF0]Rollback failed due to incorrect state:"
            + str(GameManager.state)
            + "[/color]",
            CustomLogger.LEVEL.MILD
        )
        return false

    if not FileAccess.file_exists(Dialogic.Save.get_slot_path(slot_name).path_join("game_info")):
        CustomLogger.warn(
            self,
            self._check_if_can_rollback,
            slot_name + "[color=#F00][u] game_info does not exist.[/u][/color]",
            CustomLogger.LEVEL.MILD
        )
        return false
    var info: Dictionary = Dialogic.Save.load_file(slot_name, "game_info", {})
    if (
        not info.get("game_manager") is Dictionary
        or info.game_manager.get("state") != GameManagerStates.STATES.Scenario
    ):
        UIDirector.add_system_message("Can not rollback into a state other than Scenario.")
        CustomLogger.hint(
            self,
            self._check_if_can_rollback,
            "[color=#F63] can not rollback into Navigation.[/color]",
            CustomLogger.LEVEL.MILD
        )
        return false

    return true


## On each drawn frame, this function decreases [code]last_input[/code] by [code]delta[/code].
func _process(delta: float) -> void:
    if SaveAndLoadSystemManager.restoring_data:
        return
    last_input -= delta


## Runs the parent script’s ready-time setup.
func _ready():
    super._ready()


## Sets [code]last_input[/code] to [code]input_delay[/code]; sets [code]_rollback_locked[/code] to
## true; sends [code]rollback_initiated[/code] notifications.
func _input(event: InputEvent) -> void:
    super._input(event)
    if !Dialogic.Styles.has_active_layout_node():
        return
    if Input.is_action_just_released("dialogue_rollback"):
        if last_input > 0.0:
            return
        last_input = INPUT_DELAY
        if SaveAndLoadSystemManager.restoring_data:
            return
        CustomLogger.hint(self, self._input, "Rollback tried...", CustomLogger.LEVEL.MILD)

        if _check_if_can_rollback():
            CustomLogger.hint(
                self,
                self._input,
                "Rollback initiated emitting.",
                CustomLogger.LEVEL.MILD
            )
            rollback_initiated.emit()
            _rollback_locked = true

    if Input.is_action_just_released("hide_textbox"):
        if Dialogic.Text.is_textbox_visible():
            Dialogic.Text.hide_textbox(true)
        else:
            Dialogic.Text.show_textbox(true)
