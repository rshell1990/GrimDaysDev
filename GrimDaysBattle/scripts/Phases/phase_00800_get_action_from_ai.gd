extends BattlePhase
## Battle phase responsible for get action from ai.
class_name BattlePhaseGetActionFromAI


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    super()


## Validates and prepares transient state when the phase becomes active.
func _enter() -> void:
    super()
    var unit: BattleUnit = BattleController.get_active_unit()
    var action: ActionTemplate = unit.choose_action_for_ai() if unit else null
    if action:
        BattleController.pass_cargo_to_current_phase({"action": action})
    else:
        cargo = {"skip_action": true}
        next_phase = Combat.BATTLE_STATES.PROCESS_ACTIVE_ACTION_FINISHED
    entered.emit()


## Executes the get action from ai step and advances the phase state machine when complete.
func execute() -> void:
    super()
    executed.emit()
    BattleController.go_to_next_phase(cargo)


## Publishes the phase result and clears transient state before advancing.
func _exit() -> void:
    super()
    exited.emit()
