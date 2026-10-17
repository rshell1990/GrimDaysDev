extends RefCounted
## Remembers the party's pre-battle state so retries can undo a failed attempt.
## Keeps the same unit, equipment and skill-tree objects. This data is not written to a save file.
class_name BattleRetryCheckpoint

## Shared fixed value for unit fields.
const UNIT_FIELDS := [
    "_owned_actions",
    "_action_ranks",
    "_action_grants_by_source",
    "_action_cooldowns",
    "_control_overrides",
    "_control_override_order",
    "_team_overrides",
    "_team_override_order",
    "_battle_sprite_overrides",
    "_battle_sprite_override_order",
    "attribute_progression",
]
## Saved starting state for each unit. Keeps the original unit and stat objects and copies values
## that battle can change.
var _units: Array[Dictionary] = []


## Remembers the units' current stats, stat adjustments, effects, actions and temporary changes as
## the starting point for retries.
func capture(units: Array[BattleUnit]) -> void:
    _units.clear()
    for unit in units:
        var saved := {
            "unit": unit,
            "stats": [],
            "effects": [],
            "fields": {},
            "inventory": unit.inventory,
            "inventory_state": {},
            "item_definitions": {},
            "defeat_resolved": unit.defeat_resolved,
            "kill_resolved": unit.kill_resolved
        }
        if unit.skills:
            saved.skills = unit.skills.capture_retry_state()
        if unit.inventory:
            saved.inventory_state = unit.inventory.capture_state()
            # Runtime checkpoint, not a save: keep authored definitions alive even
            # for dynamically granted supplies that have no resource path yet.
            for item: ItemBase in unit.inventory.slots.values():
                if item:
                    saved.item_definitions[item.id] = item.template
        for field in UNIT_FIELDS:
            saved.fields[field] = unit.get(field).duplicate(true)
        for stat: UnitGenericStat in unit.stat_dictionary.values():
            var mods: Array[UnitStatModifier] = []
            for modifier: UnitStatModifier in stat.mods.values():
                mods.append(_copy_modifier(modifier))
            saved.stats.append(
                {
                    "stat": stat,
                    "base": stat.Base,
                    "min": stat.Min,
                    "max": stat.Max,
                    "current": stat.Current,
                    "modifiers": mods,
                    "current_locks": stat.current_locks.duplicate(true),
                    "unlocked_current": stat.unlocked_current
                }
            )
        for holder: EffectDirectors in unit.effect_manager.triggers_to_holders.values():
            for effect in holder.get_children():
                if effect is EffectBase and not effect.is_queued_for_deletion():
                    saved.effects.append(
                        {
                            "id": effect.get_instance_id(),
                            "holder": holder,
                            "script": effect.get_script(),
                            "scene": effect.scene_file_path,
                            "name": effect.name,
                            "state": effect.capture_retry_state()
                        }
                    )
        _units.append(saved)


## Restores the remembered starting state and updates references to effects that had to be
## recreated.
## Returns false if a remembered unit no longer exists in the scene.
func restore() -> bool:
    for saved in _units:
        if not is_instance_valid(saved.unit) or not saved.unit.is_inside_tree():
            return false
        if (
            saved.inventory != null
            and (not is_instance_valid(saved.inventory) or saved.unit.inventory != saved.inventory)
        ):
            return false
    var replacements: Dictionary = {}
    for saved in _units:
        if saved.unit.skills:
            saved.unit.skills.suspended = true
    # Remove all effects first so their revoke/exit handlers cannot erase restored
    # ledger entries. No behavior is replayed while rebuilding baseline effects.
    for saved in _units:
        var unit: BattleUnit = saved.unit
        for holder: EffectDirectors in unit.effect_manager.triggers_to_holders.values():
            for effect in holder.get_children():
                if effect is EffectBase:
                    effect.remove()
                    effect.free()
        for baseline in saved.effects:
            var effect: EffectBase = ( # lint:ignore load-in-var -- Restore saved retry resource.
                load(baseline.scene).instantiate() if not baseline.scene.is_empty() else baseline.script.new()
            )
            effect.name = baseline.name
            effect.restore_retry_state(baseline.state)
            baseline.holder.add_child(effect)
            replacements[baseline.id] = effect.get_instance_id()
        unit.effect_manager.resolution_reports.clear()
        unit.effect_manager.resolution_report_order.clear()
    # Restore source-owned overrides with the reconstructed effect instance IDs.
    for saved in _units:
        var unit: BattleUnit = saved.unit
        if (
            unit.inventory
            and not unit.inventory.restore_state(saved.inventory_state, saved.item_definitions).is_empty()
        ):
            return false
        for field in UNIT_FIELDS:
            var value: Variant = saved.fields[field].duplicate(true)
            if field in ["_control_overrides", "_team_overrides", "_battle_sprite_overrides"]:
                for key in value.keys():
                    if replacements.has(key):
                        value[replacements[key]] = value[key]
                        value.erase(key)
            elif field in ["_control_override_order", "_team_override_order", "_battle_sprite_override_order"]:
                for index in value.size():
                    value[index] = replacements.get(value[index], value[index])
            unit.set(field, value)
        for saved_stat in saved.stats:
            var stat: UnitGenericStat = saved_stat.stat
            stat.current_locks = saved_stat.current_locks.duplicate(true)
            stat.unlocked_current = saved_stat.unlocked_current
            stat.mods.clear()
            for modifier in saved_stat.modifiers:
                stat.mods[modifier.modifier_id] = _copy_modifier(modifier)
            stat.restore_retry_values(saved_stat.base, saved_stat.min, saved_stat.max, saved_stat.current)
        unit.defeat_resolved = saved.defeat_resolved
        unit.kill_resolved = saved.kill_resolved
        if unit.skills and not unit.skills.restore_retry_state(saved.skills):
            return false
        # The entire dependency graph is restored before UI observers are notified.
        for saved_stat in saved.stats:
            var stat: UnitGenericStat = saved_stat.stat
            stat.value_changed.emit(stat, stat.Current, stat.Current)
        unit.last_hit_by = null
        unit.last_target = null
    return true


## Copies a stat adjustment, keeping what caused it, how it changes the stat, how long it lasts and
## its processing order.
func _copy_modifier(value: UnitStatModifier) -> UnitStatModifier:
    var copied := UnitStatModifier.create(
        value.modifier_id, value.source_id, value.stat, value.operation, value.amount, value.lifetime, value.priority
    )
    copied.contribution_cap = value.contribution_cap
    return copied
