extends BattlePhase
## Battle phase responsible for get active unit.
class_name BattlePhaseGetActiveUnit


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    super()


## Validates and prepares transient state when the phase becomes active.
func _enter() -> void:
    super()
    if active_unit:
        active_unit.on_turn_started()
        BattleController.record_turn_started()
    for unit in BattleController.get_every_unit():
        if not unit.is_active and unit not in phase_controller.inactive_since_turn_start:
            phase_controller.inactive_since_turn_start.append(unit)
    entered.emit()


## Executes the get active unit step and advances the phase state machine when complete.
func execute() -> void:
    super()
    if active_unit and active_unit.is_stunned():
        cargo = {"skip_action": true}
        next_phase = Combat.BATTLE_STATES.PROCESS_ACTIVE_ACTION_FINISHED
    elif active_unit and not active_unit.player_controlled:
        next_phase = Combat.BATTLE_STATES.GIVE_AI_CONTROL

    if BattleController.get_units_in_foe_holder().size() < 1:
        next_phase = Combat.BATTLE_STATES.VICTORY

    if BattleController.get_units_in_ally_holder().size() < 1:
        next_phase = Combat.BATTLE_STATES.DEFEAT

    executed.emit()
    BattleController.go_to_next_phase(cargo)


## Publishes the phase result and clears transient state before advancing.
func _exit() -> void:
    super()
    exited.emit()
