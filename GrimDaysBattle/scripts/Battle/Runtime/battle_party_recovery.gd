extends RefCounted
## Applies the accepted-result recovery policy without rewriting terminal combat
## history. Failed required-victory attempts use BattleRetryCheckpoint instead.
class_name BattlePartyRecovery


## Exactly once per accepted result, on the original deployed party only. Defeated
## members recover to 1 Health (subject to their effective maximum); surviving
## Health and everyone's Mana stay unchanged. Energy/Lucidity refill to maximum.
static func apply(result: BattleResult, allies: Array[BattleUnit]) -> bool:
    if not result or not result.finalized or result.party_recovered or not (result.is_victory() or result.is_defeat()):
        return false
    for unit in allies:
        if not is_instance_valid(unit):
            return false
    # Set the guard before stat signals can invoke another completion callback.
    result.party_recovered = true
    for unit in allies:
        var health := unit.get_stat(CombatStats.STATS.Health)
        if unit in result.defeated_units and health:
            health.restore_current(1.0)
        for stat_id in [CombatStats.STATS.Energy, CombatStats.STATS.Lucidity]:
            var pool := unit.get_stat(stat_id)
            if pool:
                pool.restore_current(pool.Max)
    result.recovered_party_snapshots = result._snapshot_units(allies)
    return true
