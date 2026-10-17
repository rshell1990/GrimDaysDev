extends BattlePhase
## Battle phase responsible for trigger round end efects.
class_name BattlePhaseTriggerRoundEndEffects


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    super()


## Validates and prepares transient state when the phase becomes active.
func _enter() -> void:
    super()
    entered.emit()


## Executes the trigger round end efects step and advances the phase state machine when complete.
func execute() -> void:
    super()
    var units: Array[BattleUnit] = BattleController.get_all_active_units()
    for unit in units:
        if not is_instance_valid(unit) or not unit.is_active:
            continue
        if not unit.effect_manager.has_effects_to_trigger(CombatEffects.TRIGGER.ROUND_OVER):
            continue
        await unit.resolve_effects(CombatEffects.TRIGGER.ROUND_OVER)

    var next_cargo: Dictionary = cargo if cargo is Dictionary else {}
    next_cargo["round_end"] = true
    next_phase = Combat.BATTLE_STATES.PROCESS_CHECK_FOR_DEFEATED
    executed.emit()
    BattleController.go_to_next_phase(next_cargo)


## Publishes the phase result and clears transient state before advancing.
func _exit() -> void:
    super()
    exited.emit()
