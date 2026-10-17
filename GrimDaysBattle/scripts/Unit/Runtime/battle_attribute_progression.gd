extends RefCounted
## Earned levels and committed attribute allocations. Tier resources stay immutable.
## Combat points buy the eight combat attributes; non-combat points buy Charisma/Barter.
## Skill earnings are shared across a unit's project-owned trees; their separate
## investment ledger debits that pool without changing attribute allocations.
class_name BattleAttributeProgression

## Shared source ID for persistent progression-derived stat modifiers.
const SOURCE := &"attribute_progression"
## Stat IDs that consume combat attribute points.
const COMBAT := [
    CombatStats.STATS.Strength,
    CombatStats.STATS.Vitality,
    CombatStats.STATS.Finesse,
    CombatStats.STATS.Perception,
    CombatStats.STATS.Endurance,
    CombatStats.STATS.Willpower,
    CombatStats.STATS.Mysticism,
    CombatStats.STATS.Luck
]
## Stat IDs that consume non-combat attribute points.
const NON_COMBAT := [CombatStats.STATS.Charisma, CombatStats.STATS.Barter]


## Connects level changes to progression updates, then calculates the initial grants.
static func initialize(unit: BattleUnit) -> void:
    var level := unit.get_stat(CombatStats.STATS.Level)
    if level:
        level.value_changed.connect(func(_stat, _old, _new): synchronize(unit))
    synchronize(unit)


## Breakthrough replaces the per-level pool grant at the first level of a tier.
## Automatic growth starts after breakthrough, through the inclusive tier end.
## NPC-only tiers apply to non-player templates (neither permanent nor protagonist).
static func grants(unit: BattleUnit, level: int) -> Dictionary:
    var result := {"combat": 0, "non_combat": 0, "skill": 0, "growth": {}}
    var template := unit.template_resource
    if not template or not template.leveling_tiers:
        return result
    for tier in template.leveling_tiers.all:
        if (
            not tier
            or tier.start_level < 0
            or tier.end_level < tier.start_level
            or level < tier.start_level
            or (tier.npc_only and (template.permanent or template is MainCharacterTemplate))
        ):
            continue
        var subsequent := mini(level, tier.end_level) - tier.start_level
        result.combat += maxi(tier.combat_base_grant, 0) + subsequent * maxi(tier.combat_per_level, 0)
        result.non_combat += maxi(tier.non_combat_base_grant, 0) + subsequent * maxi(tier.non_combat_per_level, 0)
        result.skill += maxi(tier.skill_points_base_grant, 0) + subsequent * maxi(tier.skill_points_per_level, 0)
        for stat_id: int in COMBAT + NON_COMBAT:
            if not unit.get_stat(stat_id):
                continue
            var growth: int = maxi(tier.level_combat_growth, 0) if stat_id in COMBAT else 0
            if stat_id in tier.specialization:
                growth += maxi(tier.specialization_growth, 0)
            var stat_name := CombatStats.get_stat_as_string(stat_id)
            result.growth[stat_name] = result.growth.get(stat_name, 0) + subsequent * growth
    return result


## Base level comes from XP, excluding temporary level modifiers. A high-water
## mark prevents repeated awards when XP falls and returns to a previous level.
static func synchronize(unit: BattleUnit) -> void:
    if unit.attribute_progression_suspended or unit.attribute_progression_busy:
        return
    var level := unit.get_stat(CombatStats.STATS.Level)
    if not level:
        return
    var attained := maxi(0, int(floor(level.Base)))
    if attained <= int(unit.attribute_progression.get("highest_level", -1)):
        return
    unit.attribute_progression_busy = true
    unit.attribute_progression["highest_level"] = attained
    unit.attribute_progression["revision"] = int(unit.attribute_progression.get("revision", 0)) + 1
    _apply_modifiers(unit)
    unit.attribute_progression_busy = false
    unit.attribute_points_changed.emit()


## Returns earned and available point totals, copied allocations and a revision number after
## checking for newly earned levels.
static func snapshot(unit: BattleUnit) -> Dictionary:
    synchronize(unit)
    var earned := grants(unit, int(unit.attribute_progression.get("highest_level", 0)))
    var allocated: Dictionary = unit.attribute_progression.get("allocated", {})
    var available := _unspent_template_pools(unit, earned)
    if unit.skills:
        available.skill = unit.skills.ledger.available_points(earned.skill)
    for stat_name in allocated:
        var pool := pool_for(CombatStats.STATS.get(String(stat_name), CombatStats.STATS.Empty))
        if not pool.is_empty():
            available[pool] -= int(allocated[stat_name])
    return {
        "available": available,
        "earned": earned,
        "allocated": allocated.duplicate(),
        "revision": int(unit.attribute_progression.get("revision", 0))
    }


## Returns [code]combat[/code] or [code]non_combat[/code] for a spendable attribute, or an empty
## string for other stats.
static func pool_for(stat_id: int) -> String:
    if stat_id in COMBAT:
        return "combat"
    if stat_id in NON_COMBAT:
        return "non_combat"
    return ""


## Validate the whole request before publishing its ledger and stat modifiers.
## expected_revision rejects old Apply callbacks, including duplicate clicks.
static func spend(unit: BattleUnit, additions: Dictionary, expected_revision: int) -> bool:
    if unit.attribute_progression_suspended or unit.attribute_progression_busy or additions.is_empty():
        return false
    var state := snapshot(unit)
    if expected_revision != state.revision:
        return false
    var costs := {"combat": 0, "non_combat": 0}
    for stat_id in additions:
        var amount: Variant = additions[stat_id]
        if not stat_id is int or not amount is int or amount <= 0:
            return false
        var pool := pool_for(stat_id)
        if pool.is_empty() or not unit.get_stat(stat_id) or amount > state.available[pool] - costs[pool]:
            return false
        costs[pool] += amount
    unit.attribute_progression_busy = true
    var allocated: Dictionary = state.allocated
    for stat_id: int in additions:
        var stat_name := CombatStats.get_stat_as_string(stat_id)
        allocated[stat_name] = int(allocated.get(stat_name, 0)) + additions[stat_id]
    unit.attribute_progression["allocated"] = allocated
    unit.attribute_progression["revision"] = state.revision + 1
    _apply_modifiers(unit)
    unit.attribute_progression_busy = false
    unit.attribute_points_changed.emit()
    return true


## Rebuilds each attribute’s persistent bonus from automatic growth and committed points. Replaces
## the bonus by its stable ID so recalculation cannot add it twice.
static func _apply_modifiers(unit: BattleUnit) -> void:
    var earned := grants(unit, int(unit.attribute_progression.get("highest_level", 0)))
    var allocated: Dictionary = unit.attribute_progression.get("allocated", {})
    for stat_id: int in COMBAT + NON_COMBAT:
        var stat := unit.get_stat(stat_id)
        if not stat:
            continue
        var amount: int = earned.growth.get(String(stat.name), 0) + allocated.get(String(stat.name), 0)
        var modifier_id := StringName("attribute_progression:" + String(stat.name))
        if amount == 0:
            stat.remove_modifier(modifier_id)
        else:
            stat.add_modifier(
                UnitStatModifier.create(
                    modifier_id,
                    SOURCE,
                    stat_id,
                    UnitStatModifier.OPERATION.FLAT_ADD,
                    amount,
                    UnitStatModifier.LIFETIME.PERSISTENT
                )
            )


## Rebuild growth with current tiers. An invalid or over-budget allocation resets the
## entire attribute build; the player, not dictionary order, chooses its replacement.
static func restore(unit: BattleUnit, data: Dictionary) -> PackedStringArray:
    unit.attribute_progression = {
        "highest_level": _saved_counter(data.get("highest_level", 0)),
        "revision": _saved_counter(data.get("revision", 0)),
        "allocated": {}
    }
    var level := unit.get_stat(CombatStats.STATS.Level)
    if level:
        unit.attribute_progression.highest_level = maxi(
            unit.attribute_progression.highest_level, int(floor(level.Base))
        )
    var earned := grants(unit, unit.attribute_progression.highest_level)
    var remaining := _unspent_template_pools(unit, earned)
    var saved: Variant = data.get("allocated", {})
    var candidate: Dictionary = {}
    var valid := saved is Dictionary
    if valid:
        for name in saved:
            if not (name is String or name is StringName):
                valid = false
                break
            var stat_id: int = CombatStats.STATS.get(String(name), CombatStats.STATS.Empty)
            var pool := pool_for(stat_id)
            var value: Variant = saved[name]
            if pool.is_empty() or not unit.get_stat(stat_id) or not _whole_number(value):
                valid = false
                break
            if value < 0 or value > remaining[pool]:
                valid = false
                break
            if value > 0:
                candidate[String(name)] = int(value)
            remaining[pool] -= int(value)
    var warnings := PackedStringArray()
    if valid:
        unit.attribute_progression.allocated = candidate
    else:
        unit.attribute_progression.revision += 1
        warnings.append(
            (
                "Attribute investments no longer fit the current budget; "
                + "all attribute points are available to reassign."
            )
        )
    _apply_modifiers(unit)
    return warnings


static func _whole_number(value: Variant) -> bool:
    return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))


static func _saved_counter(value: Variant) -> int:
    return int(value) if _whole_number(value) and value >= 0 and value < 2147483647 else 0


## Inspector-generated starting stats already contain these tier grants.
## Keep them out of the runtime spending budget without applying them as modifiers again.
static func _unspent_template_pools(unit: BattleUnit, earned: Dictionary) -> Dictionary:
    var spent: Dictionary = unit.template_resource.starting_attribute_points_spent
    return {
        "combat": maxi(0, earned.combat - maxi(0, int(spent.get("combat", 0)))),
        "non_combat": maxi(0, earned.non_combat - maxi(0, int(spent.get("non_combat", 0)))),
        "skill": earned.skill
    }
