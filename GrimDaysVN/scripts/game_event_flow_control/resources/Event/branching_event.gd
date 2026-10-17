# Editor configuration for GameEventBranching.
@icon("res://GrimDays/assets/visuals/editor_icons/tree-branch.svg")
extends GameEvent
class_name GameEventBranching

## Candidate story events checked in their configured order.
@export var branches: Array[GameEvent]


## Sends [code]VNSignalBus.event_found[/code] notifications. It pauses for
## [code]SystemHelpers.get_game_root().get_tree().create_timer(VNAnimationTimes.NEAR_INSTANT).timeout[/code]
## before continuing.
func start() -> void:
    CustomLogger.hint(self, self.start, "Examining branch: " + id, 3)
    var branch_to_start: GameEvent = null
    for branch in branches:
        if branch.is_available():
            CustomLogger.hint(self, self.start, "Available branch: " + branch.id + " has been selected.", 3)
            branch_to_start = branch
            break

    if branch_to_start == null:
        CustomLogger.warn(self, self.start, "No branches found", 4)
        return

    await SystemHelpers.get_game_root().get_tree().create_timer(VNAnimationTimes.NEAR_INSTANT).timeout
    CustomLogger.confirm(
        self,
        self.start,
        "After finding: " + branch_to_start.id + " emitting the event found signal through theVNSignalBus.",
        CustomLogger.LEVEL.MILD
    )
    VNSignalBus.event_found.emit(branch_to_start)


## Runs the parent event’s finishing behavior unless the game is in the Other mode.
func finish() -> void:
    if GameManager.state == GameManagerStates.STATES.Other:
        return
    super()
