extends EffectControlOverride
## Temporary mandatory AI ownership with unrestricted action/effect targeting. Natural round expiry restores Lucidity to
## the current
## effective maximum, then removes only this effect's control override. Explicit
## cleanup/removal does not grant recovery; settlement/retry owns that policy.
class_name EffectMadness


## Refills Lucidity and records the resource change on the final round tick, then delegates expiry
## to the base effect. Removal outside natural expiry does not refill.
func tick() -> void:
    if removed or is_queued_for_deletion():
        return
    if lifetime == EffectTemplate.LIFETIME.ROUNDS and duration == 1 and is_instance_valid(affected_unit):
        var lucidity := affected_unit.get_stat(CombatStats.STATS.Lucidity)
        if lucidity:
            var before := lucidity.Current
            lucidity.restore_current(lucidity.Max)
            _record_resource_operation(lucidity, before, lucidity.Current - before)
    super.tick()
