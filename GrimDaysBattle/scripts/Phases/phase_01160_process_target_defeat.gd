extends BattlePhase
## Battle phase responsible for process target defeat.
class_name BattlePhaseProcessDefeat
## Configures the death effect used by this phase process defeat.
@export var death_effect: EffectTemplate

## Runtime defeated unit state used by this phase process defeat.
var defeated_unit: BattleUnit


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    super()


## Validates and prepares transient state when the phase becomes active.
func _enter() -> void:
    super()
    var cursor: int = int(cargo.get("defeat_cursor", 0))
    defeated_unit = cargo.defeated[cursor]
    if death_effect:
        # Environmental and reflected damage may not have a BattleUnit source.
        defeated_unit.add_effect(defeated_unit.last_hit_by, defeated_unit, death_effect)
    entered.emit()


## Executes the process target defeat step and advances the phase state machine when complete.
func execute() -> void:
    super()
    if defeated_unit.effect_manager:
        await BattleEncounterEffects.resolve_unit_defeat(defeated_unit, Callable())
    executed.emit()
    BattleController.go_to_next_phase(cargo)


## Publishes the phase result and clears transient state before advancing.
func _exit() -> void:
    super()
    exited.emit()
