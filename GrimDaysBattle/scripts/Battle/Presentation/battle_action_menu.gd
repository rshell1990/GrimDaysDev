extends PanelContainer
## Retains Back/retry controls and hidden debug status alongside the authored battle HUD.
class_name BattleActionMenu

## Requests a retry for the supplied battle session_id. The argument is an attempt identifier, not
## the count of retries.
signal retry_requested(attempt: int)
## Battle attempt number sent with a retry request, or -1 once the request has been sent.
var _retry_attempt: int = -1

## Turn manager that receives the player's action, pass and cancel choices.
@export var flow: BattleEncounterFlow
## Label describing the current turn phase, retry prompt or error.
@onready var status: Label = $Content/Status
## Legacy container retained hidden; the actor's authored wheel owns ordinary input.
@onready var actions: HBoxContainer = $Content/Actions
## Button that cancels target selection and returns to choosing an action.
@onready var back: Button = $Content/Back
## Button that requests a retry using the remembered battle attempt number.
@onready var retry: Button = $Content/Retry


## Connects flow updates and menu input, then displays the current flow state.
func _ready() -> void:
    flow.action_required.connect(_on_action_required)
    flow.state_changed.connect(_refresh)
    back.pressed.connect(flow.cancel_selection)
    retry.pressed.connect(
        func():
            var attempt := _retry_attempt
            _retry_attempt = -1
            retry.hide()
            retry_requested.emit(attempt)
    )
    _refresh()


## Refreshes auxiliary controls; BattleProductionHUD receives the same input request.
func _on_action_required(
    _input_turn: int, _actor: BattleUnit, _available: Array[ActionTemplate]
) -> void:
    _refresh()


## Updates action/back visibility and status text from the flow's current phase.
func _refresh() -> void:
    retry.hide()
    actions.hide()
    status.hide()
    visible = flow.state == BattleEncounterFlow.STATE.TARGETS
    back.visible = flow.state == BattleEncounterFlow.STATE.TARGETS
    if back.visible:
        back.grab_focus()
    match flow.state:
        BattleEncounterFlow.STATE.ACTION:
            status.text = "%s — choose an action" % flow.active_unit.template_resource.display_name
        BattleEncounterFlow.STATE.TARGETS:
            status.text = "Choose a target. Back cancels without spending resources."
        BattleEncounterFlow.STATE.STOPPED:
            status.text = (
                "Battle finished"
                if flow.coordinator and flow.coordinator.current_result
                else "Waiting for encounter"
            )
        _:
            status.text = "Resolving turn…"


## Shows the retry prompt and remembers which battle attempt it belongs to.
## The attempt argument is the battle manager's session_id, not the number of retries.
func show_retry(attempt: int) -> void:
    show()
    _retry_attempt = attempt
    actions.hide()
    back.hide()
    status.text = "Victory is required to continue. Try this battle again."
    retry.show()
    retry.grab_focus()


## Hides action and retry controls and displays the supplied failure message.
func show_error(message: String) -> void:
    hide()
    actions.hide()
    back.hide()
    retry.hide()
    status.text = message


## Cancels target selection when Back is released, and marks that input as handled so other controls
## do not also act on it.
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_released("back") and flow.state == BattleEncounterFlow.STATE.TARGETS:
        flow.cancel_selection()
        get_viewport().set_input_as_handled()
