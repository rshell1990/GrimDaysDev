extends Node
## Coordinates battle party manager behavior for the battle system.
class_name BattlePartyManager

## Emitted when party changed.
signal party_changed(units: Array[BattleUnit])
## Emitted when restored.
signal restored

## Fixed max active party size value shared by all party manager instances.
const MAX_ACTIVE_PARTY_SIZE: int = 4
## Prototype stash capacity; separate from the nine-slot combat inventories.
const STASH_SIZE: int = 64
## Fixed resource stats value shared by all party manager instances.
const RESOURCE_STATS: Array[CombatStats.STATS] = [
    CombatStats.STATS.Health,
    CombatStats.STATS.Energy,
    CombatStats.STATS.Mana,
    CombatStats.STATS.Lucidity,
]

## Stable save name used to correlate or persist this party manager.
var save_name: String = "battle_party"
## Lookup table that stores runtime units for deterministic runtime access.
var runtime_units: Dictionary[StringName,BattleUnit]
## Ordered runtime collection of active party ids.
var active_party_ids: Array[StringName]
## Production rosters borrow units exclusively without changing scene ownership.
var _encounter_owner: WeakRef
## Preparation is a distinct lease: inventory operations remain available, but
## no encounter can borrow the party until the modal closes.
var _preparation_owner: WeakRef
## Shared out-of-combat storage. It does not contribute to any unit's Weight.
var stash: Inventory


## The stash belongs to the persistent party service, not to an encounter scene.
func _init() -> void:
    stash = Inventory.new()
    stash.name = &"Stash"
    stash.size = STASH_SIZE
    stash.initialize()
    add_child(stash)


## Empty unit IDs identify the stash. Transfers are preparation operations, never
## a way to lend an item to a combatant while an encounter owns the party.
func transfer_item(from_unit_id: StringName, to_unit_id: StringName, slot: int, amount: int = 1) -> bool:
    if not can_prepare_inventory():
        return false
    var source: Inventory = _inventory_for(from_unit_id)
    var destination: Inventory = _inventory_for(to_unit_id)
    return source != null and destination != null and source.transfer_to(destination, slot, amount)


## Shared preparation gate for transfers and equipment changes, including retries.
func can_prepare_inventory() -> bool:
    return not (_encounter_owner and is_instance_valid(_encounter_owner.get_ref()))


## Idempotent story milestone, not an additive XP reward or template edit. Raise
## earned XP to the requested authored threshold, preserving any higher earnings
## and all player allocations. Normal progression awards unspent points once.
func ensure_minimum_level(unit_id: StringName, requested_level: int) -> bool:
    var unit: BattleUnit = runtime_units.get(unit_id)
    if not can_prepare_inventory() or not is_instance_valid(unit) or requested_level < 0:
        return false
    var amount := BattleUnitCreation.experience_for_level(unit, requested_level)
    var experience := unit.get_stat(CombatStats.STATS.Experience)
    if amount < 0 or not experience:
        return false
    var definition := unit.get_stat(CombatStats.STATS.Level).original_template as UnitCalculatedStatTemplate
    # Unlike starting-level clamping, an unreachable story milestone must fail
    # without mutating progression. Do not silently grant the highest available level.
    if definition.calculate_base(amount) < requested_level:
        return false
    if experience.Base < amount:
        experience.set_base(amount)
    return true


## Separate balances and committed allocations for the selected persistent ally.
func get_attribute_points(unit_id: StringName) -> Dictionary:
    var unit: BattleUnit = runtime_units.get(unit_id)
    return BattleAttributeProgression.snapshot(unit) if is_instance_valid(unit) else {}


## Preparation-only, atomic spending with optimistic revision validation.
func spend_attribute_points(unit_id: StringName, additions: Dictionary, revision: int) -> bool:
    var unit: BattleUnit = runtime_units.get(unit_id)
    return (
        can_prepare_inventory()
        and is_instance_valid(unit)
        and BattleAttributeProgression.spend(unit, additions, revision)
    )


## Project skill commands require the exact active preparation owner as well as
## a current view revision. Closed/stale panels cannot buy ranks during a battle
## or a later visit. Point earnings and gate values never come from UI input.
func purchase_skills(
    unit_id: StringName, additions: Dictionary, revision: int, preparation_owner: Node
) -> PackedStringArray:
    var unit: BattleUnit = runtime_units.get(unit_id)
    if not owns_preparation(preparation_owner) or not is_instance_valid(unit) or not unit.skills:
        return PackedStringArray(["Skill purchases require this unit's active preparation session."])
    return unit.skills.purchase(additions, revision)


## Read-only capability check for view enablement and command authorization.
func owns_preparation(owner_node: Node) -> bool:
    return (
        can_prepare_inventory()
        and is_instance_valid(owner_node)
        and _preparation_owner != null
        and _preparation_owner.get_ref() == owner_node
    )


## Equipment must first be assigned to the unit; shared stash is never implicit.
func equip_inventory_item(unit_id: StringName, inventory_slot: int, equipment_slot: int) -> bool:
    return (
        can_prepare_inventory()
        and BattleEquipmentLoadout.equip_from_inventory(runtime_units.get(unit_id), inventory_slot, equipment_slot)
    )


## Returns gear to its wearer's inventory, or fails unchanged if storage is full.
func unequip_inventory_item(unit_id: StringName, equipment_slot: int) -> bool:
    return (
        can_prepare_inventory()
        and BattleEquipmentLoadout.unequip_to_inventory(runtime_units.get(unit_id), equipment_slot)
    )


## Looks up an explicitly selected owner; unknown units never fall back to stash.
func _inventory_for(unit_id: StringName) -> Inventory:
    if unit_id.is_empty():
        return stash
    var unit: BattleUnit = runtime_units.get(unit_id)
    return unit.inventory if is_instance_valid(unit) else null


## Reserves the party for the supplied battle owner. Returns false if another owner still exists and
## has reserved it.
func acquire_encounter(owner_node: Node) -> bool:
    if not is_instance_valid(owner_node) or (_preparation_owner and is_instance_valid(_preparation_owner.get_ref())):
        return false
    var current_owner: Object = _encounter_owner.get_ref() if _encounter_owner else null
    if current_owner and current_owner != owner_node:
        return false
    _encounter_owner = weakref(owner_node)
    return true


## Makes the party available to another battle, but only if the supplied owner currently holds the
## reservation.
func release_encounter(owner_node: Node) -> void:
    if _encounter_owner and _encounter_owner.get_ref() == owner_node:
        _encounter_owner = null


## Acquires an exclusive preparation session without treating it as combat.
func acquire_preparation(owner_node: Node) -> bool:
    if not is_instance_valid(owner_node) or not can_prepare_inventory():
        return false
    var current_owner: Object = _preparation_owner.get_ref() if _preparation_owner else null
    if current_owner and current_owner != owner_node:
        return false
    _preparation_owner = weakref(owner_node)
    return true


## A stale panel cannot release a newer panel's reservation.
func release_preparation(owner_node: Node) -> void:
    if _preparation_owner and _preparation_owner.get_ref() == owner_node:
        _preparation_owner = null


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    VNSignalBus.reset_sub_systems.connect(reset)
    reset()
    _register_for_saving.call_deferred()


## Resets reset for this party manager.
func reset(starting_equipment: bool = true) -> void:
    _clear_units()
    stash.clear_items()
    var templates: Dictionary = BattleRepository.get_repository(BattleRepository.BATTLE_UNIT_TEMPLATES)
    var template_ids: Array = templates.keys()
    template_ids.sort()
    for template_id in template_ids:
        var template: BattleUnitTemplate = templates[template_id]
        if not template or not template.permanent:
            continue
        var unit := BattleUnit.create(template, starting_equipment)
        if not unit:
            (
                CustomLogger
                . error(
                    self,
                    reset,
                    "Could not create permanent unit %s." % template_id,
                    CustomLogger.LEVEL.IMPORTANT,
                )
            )
            continue
        unit.name = template.id
        add_child(unit)
        runtime_units[template.id] = unit
        if active_party_ids.size() < MAX_ACTIVE_PARTY_SIZE:
            active_party_ids.append(template.id)
    party_changed.emit(get_active_party())


## Returns available units for this party manager.
func get_available_units() -> Array[BattleUnit]:
    var units: Array[BattleUnit] = []
    for unit in runtime_units.values():
        units.append(unit)
    return units


## Returns active party for this party manager.
func get_active_party() -> Array[BattleUnit]:
    var units: Array[BattleUnit] = []
    for unit_id in active_party_ids:
        var unit: BattleUnit = runtime_units.get(unit_id)
        if unit and unit.is_active:
            units.append(unit)
    return units


## Sets active party for this party manager.
func set_active_party(unit_ids: Array) -> bool:
    if not can_prepare_inventory() or unit_ids.size() > MAX_ACTIVE_PARTY_SIZE:
        return false
    var unique_ids: Dictionary = {}
    var normalized_ids: Array[StringName] = []
    for value in unit_ids:
        var unit_id := StringName(value)
        if not runtime_units.has(unit_id) or unique_ids.has(unit_id):
            return false
        unique_ids[unit_id] = true
        normalized_ids.append(unit_id)
    active_party_ids.assign(normalized_ids)
    party_changed.emit(get_active_party())
    return true


## Returns whether party manager owns unit.
func owns_unit(unit: BattleUnit) -> bool:
    return unit != null and runtime_units.get(unit.template_resource.id if unit.template_resource else &"") == unit


## Returns ownership of unit for this party manager.
func reclaim_unit(unit: BattleUnit) -> bool:
    if not owns_unit(unit):
        return false
    if unit.get_parent() == self:
        return true
    var old_parent := unit.get_parent()
    if old_parent:
        old_parent.remove_child(unit)
    add_child(unit)
    return true


## Returns a save-safe snapshot of this party manager's persistent state.
func _get_state() -> Dictionary:
    var units: Dictionary = {}
    for unit_id in runtime_units:
        units[unit_id] = _serialize_unit(runtime_units[unit_id])
    return {
        "active_party": active_party_ids.duplicate(),
        "units": units,
        "stash": stash.capture_state(),
    }


## Restores this party manager from a serialized state snapshot.
func restore(data: Dictionary) -> void:
    # Saved occupied slots, not starting defaults, are the load authority.
    reset(false)
    for warning in stash.restore_state(data.get("stash", {})):
        CustomLogger.warn(self, restore, warning, CustomLogger.LEVEL.IMPORTANT)
    var saved_units: Dictionary = data.get("units", {})
    for unit_id in runtime_units:
        if not saved_units.has(unit_id) and not saved_units.has(String(unit_id)):
            # Newly authored permanent characters have no saved loadout yet.
            BattleEquipmentLoadout.stage_starting(runtime_units[unit_id])
    for unit_id in saved_units:
        var unit: BattleUnit = runtime_units.get(StringName(unit_id))
        if unit:
            _restore_unit(unit, saved_units[unit_id])
    var requested_party: Array[StringName] = []
    for unit_id in data.get("active_party", []):
        requested_party.append(StringName(unit_id))
    if not set_active_party(requested_party):
        CustomLogger.warn(
            self, restore, "Saved active party was invalid; using permanent defaults.", CustomLogger.LEVEL.IMPORTANT
        )
    restored.emit()


## Serializes unit for this party manager.
func _serialize_unit(unit: BattleUnit) -> Dictionary:
    BattleAttributeProgression.synchronize(unit)
    var stats: Dictionary = {}
    for stat_name in unit.stat_dictionary:
        var stat: UnitGenericStat = unit.stat_dictionary[stat_name]
        var modifiers: Array[Dictionary] = []
        for modifier in stat.mods.values():
            if (
                modifier.lifetime != UnitStatModifier.LIFETIME.PERSISTENT
                or String(modifier.source_id).begins_with("equipment:")
                or modifier.source_id == BattleAttributeProgression.SOURCE
            ):
                continue
            (
                modifiers
                . append(
                    {
                        "modifier_id": modifier.modifier_id,
                        "source_id": modifier.source_id,
                        "stat": modifier.stat,
                        "operation": modifier.operation,
                        "amount": modifier.amount,
                        "priority": modifier.priority,
                    }
                )
            )
            if modifier.operation == UnitStatModifier.OPERATION.CAPPED_ADD:
                modifiers.back()["contribution_cap"] = modifier.contribution_cap
        stats[stat_name] = {
            "base": stat.Base,
            "template_base": stat.original_template.starting_amount,
            "current": stat.Current,
            "modifiers": modifiers,
        }
    return {
        "stats": stats,
        "actions": unit.serialize_action_state(),
        "skill_investment": unit.skills.capture() if unit.skills else {},
        "attribute_progression": unit.attribute_progression.duplicate(true),
        "equipment": BattleEquipmentLoadout.capture(unit),
        "inventory": unit.inventory.capture_state() if unit.inventory else {},
    }


## Restores unit for this party manager.
func _restore_unit(unit: BattleUnit, data: Dictionary) -> void:
    if unit.skills:
        unit.skills.begin_restore()
    unit.attribute_progression_suspended = true
    for stat: UnitGenericStat in unit.stat_dictionary.values():
        stat.remove_modifiers_from_source(BattleAttributeProgression.SOURCE)
    if unit.inventory:
        for warning in unit.inventory.restore_state(data.get("inventory", {})):
            CustomLogger.warn(self, _restore_unit, warning, CustomLogger.LEVEL.IMPORTANT)
    var saved_stats: Dictionary = data.get("stats", {})
    var baseline_changed := false
    for stat_name in saved_stats:
        var stat: UnitGenericStat = unit.stat_dictionary.get(StringName(stat_name))
        if not stat:
            continue
        var saved_stat: Dictionary = saved_stats[stat_name]
        if _baseline_changed(unit, stat, saved_stat):
            baseline_changed = true
        if stat.id in CombatStats.FLAT_STATS:
            stat.set_base(_restored_base(unit, stat, saved_stat))
        for saved_modifier in saved_stat.get("modifiers", []):
            if (
                String(saved_modifier.source_id).begins_with("equipment:")
                or String(saved_modifier.source_id).begins_with("project_skill:")
                or saved_modifier.source_id == BattleAttributeProgression.SOURCE
            ):
                continue  # Equipment definitions are the only authority for these grants.
            var restored_modifier := (
                UnitStatModifier
                . create(
                    StringName(saved_modifier.modifier_id),
                    StringName(saved_modifier.source_id),
                    int(saved_modifier.stat),
                    int(saved_modifier.operation),
                    float(saved_modifier.amount),
                    UnitStatModifier.LIFETIME.PERSISTENT,
                    int(saved_modifier.priority),
                )
            )
            restored_modifier.contribution_cap = float(saved_modifier.get("contribution_cap", INF))
            stat.add_modifier(restored_modifier)
    # Rebuild ownership and maximum-stat grants before current pools/cooldowns.
    var actions: Dictionary = data.get("actions", {})
    unit.restore_action_state(actions, false)
    for warning in BattleEquipmentLoadout.restore(unit, data.get("equipment", [])):
        CustomLogger.warn(self, _restore_unit, warning, CustomLogger.LEVEL.IMPORTANT)
    for warning in BattleAttributeProgression.restore(unit, data.get("attribute_progression", {})):
        CustomLogger.warn(self, _restore_unit, warning, CustomLogger.LEVEL.IMPORTANT)
    unit.attribute_progression_suspended = false
    if unit.skills:
        var investment: Variant = data.get("skill_investment", {"version": 1, "ranks": {}})
        for warning in unit.skills.restore(investment):
            CustomLogger.warn(self, _restore_unit, warning, CustomLogger.LEVEL.IMPORTANT)
    unit.restore_action_cooldowns(actions.get("cooldowns", {}))
    for stat_type in RESOURCE_STATS:
        var stat: UnitGenericStat = unit.get_stat(stat_type)
        if not stat:
            continue
        if baseline_changed:
            stat.restore_current(stat.Max)
            continue
        if not saved_stats.has(stat.name):
            continue
        var desired_current := float(saved_stats[stat.name].get("current", stat.Current))
        stat.restore_current(desired_current)


## Compare authored baselines, not saved runtime offsets. Legacy flat bases are the
## only available evidence of a baseline repair when metadata is absent.
func _baseline_changed(unit: BattleUnit, stat: UnitGenericStat, saved: Dictionary) -> bool:
    if not unit.template_resource.permanent or stat.id in [CombatStats.STATS.Experience, CombatStats.STATS.Sanity]:
        return false
    var baseline: Variant = saved.get("template_base")
    if (baseline is int or baseline is float) and is_finite(float(baseline)):
        return not is_equal_approx(float(baseline), stat.original_template.starting_amount)
    var saved_base: Variant = saved.get("base")
    if stat.id in CombatStats.FLAT_STATS and (saved_base is int or saved_base is float):
        return (
            is_finite(float(saved_base)) and not is_equal_approx(float(saved_base), _restored_base(unit, stat, saved))
        )
    return false


## XP and Sanity are character history. Other permanent-unit bases follow current
## balance data plus explicit saved runtime changes relative to the former baseline.
## Legacy saves lack that baseline: use current defaults, retaining separate ledgers/modifiers.
func _restored_base(unit: BattleUnit, stat: UnitGenericStat, saved: Dictionary) -> float:
    var base_value: Variant = saved.get("base", stat.Base)
    if not (base_value is int or base_value is float) or not is_finite(float(base_value)):
        return stat.Base
    if not unit.template_resource.permanent or stat.id in [CombatStats.STATS.Experience, CombatStats.STATS.Sanity]:
        return float(base_value)
    var baseline: Variant = saved.get("template_base")
    if (baseline is int or baseline is float) and is_finite(float(baseline)):
        return stat.original_template.starting_amount + float(base_value) - float(baseline)
    return stat.original_template.starting_amount


## Clears units for this party manager.
func _clear_units() -> void:
    active_party_ids.clear()
    for unit in runtime_units.values():
        if not is_instance_valid(unit):
            continue
        var old_parent: Node = unit.get_parent()
        if old_parent:
            old_parent.remove_child(unit)
        unit.queue_free()
    runtime_units.clear()


## Registers for saving for this party manager.
func _register_for_saving() -> void:
    if is_instance_valid(SaveAndLoadSystemManager):
        SaveAndLoadSystemManager.add_node(self)
