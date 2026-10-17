extends EffectBase
## One deterministic pending-turn swap. Does not change speed, consume a turn,
## interrupt the actor or manufacture a next-round delay when no swap is possible.
class_name EffectDelayTurn

## Whether the most recent apply cycle moved the target later in pending turn order.
var delayed: bool = false


## Requests one pending-turn delay from the recipient's roster when both units belong to the
## encounter. Emits a turn-order operation only on success and completes the apply cycle in either
## case.
func apply() -> void:
    if not _begin_apply():
        return
    delayed = false
    if sender is BattleUnit and targeting is BattleUnit:
        var roster := targeting.participant_source as BattleEncounterRoster
        if is_instance_valid(roster) and sender in roster.get_participants():
            delayed = roster.delay_pending_turn(targeting)
        if delayed:
            (
                targeting
                . turn_order_operation_resolved
                . emit(
                    {
                        "effect_id": id,
                        "instance_id": get_instance_id(),
                        "source_id": source_id,
                        "source": sender,
                        "recipient": targeting,
                        "trigger": trigger,
                        "resolved_change": 1.0,
                    }
                )
            )
    _finish_apply()


## Returns the effect ID and whether a delay occurred, or an empty dictionary when this cycle did
## not apply.
func get_resolution_report() -> Dictionary:
    return {"effect_id": id, "delayed": delayed} if applied_this_cycle else {}
