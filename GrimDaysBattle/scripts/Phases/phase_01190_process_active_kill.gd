extends BattlePhase
## Battle phase responsible for process active kill.
class_name BattlePhaseProcessKill

## Runtime defeated unit state used by this phase process kill.
var defeated_unit: BattleUnit


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    super()


## Validates and prepares transient state when the phase becomes active.
func _enter() -> void:
    super()
    var cursor: int = int(cargo.get("defeat_cursor", 0))
    defeated_unit = cargo.defeated[cursor]
    entered.emit()


## Executes the process active kill step and advances the phase state machine when complete.
func execute() -> void:
    super()
    await trigger_kill_effects_for(defeated_unit)
    executed.emit()
    var processed: Array = cargo.get("processed", [])
    if defeated_unit not in processed:
        processed.append(defeated_unit)
    cargo["processed"] = processed
    cargo["defeat_cursor"] = int(cargo.get("defeat_cursor", 0)) + 1
    BattleController.go_to_next_phase(cargo)


## Triggers kill effects for for this phase process kill.
func trigger_kill_effects_for(unit: BattleUnit) -> void:
    if not is_instance_valid(unit) or unit.is_active or unit.kill_resolved:
        return
    unit.kill_resolved = true
    var killer = unit.last_hit_by if is_instance_valid(unit) else null
    # A defeat is valid without a unit source (environment, recoil, expiration).
    if not is_instance_valid(killer) or killer is not BattleUnit or not killer.is_active:
        return
    await killer.resolve_effects(CombatEffects.TRIGGER.KILL)


## Publishes the phase result and clears transient state before advancing.
func _exit() -> void:
    super()
    exited.emit()
