extends BattlePhase
## Battle phase responsible for end round.
class_name BattlePhaseEndRound

## Whether the completed condition currently holds.
var completed: bool
## Lifecycle that resolves round-end operations and duration countdown for this legacy phase.
var lifecycle: BattleEncounterEffects


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    super()
    lifecycle = BattleEncounterEffects.new()


## Validates and prepares transient state when the phase becomes active.
func _enter() -> void:
    super()
    completed = false
    entered.emit()


## Executes the end round step and advances the phase state machine when complete.
func execute() -> void:
    if completed:
        return
    completed = true
    super()
    # The consolidated boundary signal resolves the round that just finished, so
    # resolving here keeps one countdown per round without a second emitter.
    SignalBus.tick.emit(StringName("legacy_round_end:%s" % get_instance_id()))
    cargo = null
    executed.emit()
    BattleController.go_to_next_phase(cargo)


## Publishes the phase result and clears transient state before advancing.
func _exit() -> void:
    super()
    exited.emit()
