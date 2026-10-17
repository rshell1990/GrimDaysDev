extends BattlePhase
## Battle phase responsible for check for defeated.
class_name BattlePhaseCheckForDefeated


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    super()


## Validates and prepares transient state when the phase becomes active.
func _enter() -> void:
    super()
    if cargo is not Dictionary:
        cargo = {}
    var the_defeated: Array = []
    the_defeated.assign(cargo.get("defeated", []))
    var processed: Array = cargo.get("processed", [])
    var all_units = BattleController.get_every_unit()
    assert(not all_units.is_empty() and all_units != null)
    for unit in all_units:
        if unit in phase_controller.inactive_since_turn_start:
            continue
        if not unit.is_active and unit not in the_defeated and unit not in processed:
            the_defeated.append(unit)

        (
            CustomLogger
            . hint(
                self,
                _enter,
                "Unit %s has %s health." % [unit, unit.get_stat(CombatStats.STATS.Health).Current],
                CustomLogger.LEVEL.VERY_VERBOSE,
            )
        )

    CustomLogger.hint(self, _enter, "Defeated units: " + str(the_defeated), CustomLogger.LEVEL.VERY_VERBOSE)
    cargo["defeated"] = the_defeated
    cargo["defeat_cursor"] = clampi(int(cargo.get("defeat_cursor", 0)), 0, the_defeated.size())
    entered.emit()


## Executes the check for defeated step and advances the phase state machine when complete.
func execute() -> void:
    super()
    if cargo.defeat_cursor < cargo.defeated.size():
        next_phase = Combat.BATTLE_STATES.PROCESS_UPDATE_TURN_ORDER
    elif cargo.get("round_end", false):
        # A ROUND_OVER operation may eliminate a team after the final normal
        # action. Resolve that outcome now so an empty team cannot begin a
        # phantom round merely to be detected by GetActiveUnit.
        if BattleController.get_units_in_ally_holder().is_empty():
            next_phase = Combat.BATTLE_STATES.DEFEAT
        elif BattleController.get_units_in_foe_holder().is_empty():
            next_phase = Combat.BATTLE_STATES.VICTORY
        else:
            next_phase = Combat.BATTLE_STATES.END_ROUND
    executed.emit()
    BattleController.go_to_next_phase(cargo)


## Publishes the phase result and clears transient state before advancing.
func _exit() -> void:
    super()
    exited.emit()
