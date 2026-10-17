extends BattlePhase
## Battle phase responsible for process active before hit.
class_name BattlePhaseProcessActiveBeforeHit


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    super()


## Validates and prepares transient state when the phase becomes active.
func _enter() -> void:
    super()
    Combat.add_effects_from_category(selected_action, active_unit, targets[0], CombatEffects.TRIGGER.ATTACKING)
    await get_tree().create_timer(AnimationTimes.NEAR_INSTANT).timeout
    entered.emit()


## Executes the process active before hit step and advances the phase state machine when complete.
func execute() -> void:
    super()
    await active_unit.resolve_effects(CombatEffects.TRIGGER.ATTACKING)
    executed.emit()
    BattleController.go_to_next_phase()


## Publishes the phase result and clears transient state before advancing.
func _exit() -> void:
    super()
    exited.emit()
