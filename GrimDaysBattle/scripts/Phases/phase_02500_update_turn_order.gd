extends BattlePhase
## Battle phase responsible for update turn order.
class_name BattlePhaseUpdateTurnOrder


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    super()


## Validates and prepares transient state when the phase becomes active.
func _enter() -> void:
    super()
    entered.emit()


## Executes the update turn order step and advances the phase state machine when complete.
func execute() -> void:
    super()
    if cargo is Dictionary and cargo.has("defeated"):
        var removed_count: int = clampi(
            int(cargo.get("turn_order_removed_count", 0)),
            0,
            cargo.defeated.size(),
        )
        var newly_defeated: Array = cargo.defeated.slice(removed_count)
        if not newly_defeated.is_empty():
            BattleController.update_turn_order_on_unit_defeat(newly_defeated)
        cargo["turn_order_removed_count"] = cargo.defeated.size()
    executed.emit()
    BattleController.go_to_next_phase(cargo)


## Publishes the phase result and clears transient state before advancing.
func _exit() -> void:
    super()
    exited.emit()
