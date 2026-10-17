extends RefCounted
## Defend is two ordinary source-owned, one-round stat effects.
class_name BattleDefend

const EFFECTS = [
    preload("res://GrimDaysBattle/resources/effects/defend_physical.tres"),
    preload("res://GrimDaysBattle/resources/effects/defend_magical.tres"),
]
const RESISTANCES = [CombatStats.STATS.PhysicalResistance, CombatStats.STATS.MagicResistance]


static func can_defend(unit: BattleUnit) -> bool:
    if not is_instance_valid(unit) or not unit.is_active:
        return false
    for stat_id in RESISTANCES:
        var stat := unit.get_stat(stat_id)
        if stat and stat.Current < 90.0:
            return true
    return false


static func apply(unit: BattleUnit, continuation: Callable) -> void:
    for definition: EffectCappedChangeStatTemplate in EFFECTS:
        if not continuation.call():
            return
        if not unit.get_stat(definition.stat):
            continue
        var effect := unit.add_effect(unit, unit, definition, {"source_id": &"battle_command:defend"})
        if effect:
            await (effect.get_parent() as EffectDirectors).trigger_selected_effects(
                definition.id, [effect], continuation
            )
