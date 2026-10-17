extends Control


## Outside initialization, waits for the owner to be ready and asks whether to show the tutorial.
## Starts its animation on acceptance or exits on refusal.
func _ready() -> void:
    if GameManager.state == GameManagerStates.STATES.Init:
        return
    await owner.ready
    ConfirmationModal.customize("View navigation tutorial?", "", "Yes", "No")

    var confirmed = await ConfirmationModal.prompt(true)

    if not confirmed:
        exit()
        return

    DialogicRelay.start_animation("start")


## Asks the containing scene to close the tutorial.
func exit() -> void:
    var root = get_parent().get_parent()
    root.exit_scene()
