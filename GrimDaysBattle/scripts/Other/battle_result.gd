extends RefCounted
## Final summary of one battle. Live references support immediate consumers;
## value snapshots remain usable after combatants and their scene are freed.
class_name BattleResult

## Terminal states recognized by phase-driven and headless battles.
enum OUTCOME {
    NONE,
    VICTORY,
    DEFEAT,
    DRAW,
    ERROR,
}

## Stable identifier supplied when the encounter was queued.
var encounter_id: StringName
## Terminal result; [constant OUTCOME.NONE] until finalization.
var outcome: OUTCOME = OUTCOME.NONE
## Seed used for deterministic unit random streams.
var battle_seed: int
## Number of combatant turns resolved in this session.
var turns: int
## Number of rounds started in this session.
var rounds: int
## Live ally references that remained active at finalization.
var surviving_allies: Array[BattleUnit]
## Escaped allies are living original participants, never defeated by escape.
var escaped_allies: Array[BattleUnit] = []
## Live foe references that remained active at finalization.
var surviving_foes: Array[BattleUnit]
## Live references to participants that were inactive at finalization.
var defeated_units: Array[BattleUnit]
## Stable team identifiers that won this encounter.
var winning_teams: Array[StringName]
## Stable team identifiers that lost this encounter.
var defeated_teams: Array[StringName]
## Value snapshots remain valid after the battle scene and runtime units are freed.
var ally_snapshots: Array[Dictionary]
## Value snapshots of foe state captured before runtime cleanup.
var foe_snapshots: Array[Dictionary]
## Authoritative action-resolution events in chronological order.
var combat_events: Array
## Reward payload populated by the encounter or reward system.
var rewards: Dictionary
## Deep-copied navigation or scenario context used after leaving battle.
var return_context: Dictionary
## Human-readable failure or draw reason when applicable.
var error: String
## Whether terminal collections and snapshots were already captured.
var finalized: bool
## Recovery is a settlement operation, separate from the terminal battle snapshot.
var party_recovered: bool
## Party state after accepted-result recovery; never overwrites ally_snapshots.
var recovered_party_snapshots: Array[Dictionary]
## Exactly-once settlement state and value-only receipt, independent from requests.
var rewards_settled: bool
## Guards settlement against reentrant reward callbacks.
var reward_settlement_in_progress: bool
## Records the accepted inventory and currency changes from reward settlement.
var reward_receipt: Dictionary
## Overflow negotiation preserves the original offer and records player declines.
var reward_offer: Array = []
## Tracks offered reward quantities deliberately declined by the player.
var discarded_rewards: Dictionary[int,int] = {}
## Indicates remaining loot could not fit and requires a reward-inventory decision.
var reward_capacity_blocked: bool


## Captures terminal state exactly once; returns [code]false[/code] on repeats.
func finalize(
    new_outcome: OUTCOME,
    allies: Array[BattleUnit],
    foes: Array[BattleUnit],
    new_error: String = "",
) -> bool:
    if finalized:
        return false
    finalized = true
    outcome = new_outcome
    error = new_error
    surviving_allies = _active_units(allies)
    surviving_foes = _active_units(foes)
    ally_snapshots = _snapshot_units(allies)
    foe_snapshots = _snapshot_units(foes, true)
    _set_team_outcome(new_outcome)
    for unit in allies + foes:
        if is_instance_valid(unit) and not unit.is_active:
            defeated_units.append(unit)
    return true


## Copies encounter rewards so later authoring mutations cannot rewrite results.
func set_rewards(value: Dictionary) -> void:
    rewards = value.duplicate(true)


## Returns whether the session ended in player victory.
func is_victory() -> bool:
    return outcome == OUTCOME.VICTORY


## Returns whether the session ended in player defeat.
func is_defeat() -> bool:
    return outcome == OUTCOME.DEFEAT


## Filters [param units] to valid combatants that can still act.
func _active_units(units: Array[BattleUnit]) -> Array[BattleUnit]:
    var active: Array[BattleUnit] = []
    for unit in units:
        if is_instance_valid(unit) and unit.is_active:
            active.append(unit)
    return active


## Captures save-safe identity, activity, and health values for valid units.
func _snapshot_units(units: Array[BattleUnit], include_loot: bool = false) -> Array[Dictionary]:
    var snapshots: Array[Dictionary] = []
    for unit in units:
        if not is_instance_valid(unit):
            continue
        var health: UnitGenericStat = unit.get_stat(CombatStats.STATS.Health)
        var template_id: StringName = unit.template_resource.id if unit.template_resource else &""
        var snapshot := {
            "id": template_id,
            "display_name": unit.template_resource.display_name if unit.template_resource else String(template_id),
            "save_name": unit.save_name,
            "team_id": unit.team_id,
            "active": unit.is_active,
            "escaped": unit in escaped_allies,
            "health": health.Current if health else 0.0,
            "max_health": health.Max if health else 0.0,
        }
        for stat_id in [CombatStats.STATS.Energy, CombatStats.STATS.Mana, CombatStats.STATS.Lucidity]:
            var pool := unit.get_stat(stat_id)
            if pool:
                snapshot[CombatStats.get_stat_as_string(stat_id).to_lower()] = pool.Current
        if include_loot:
            snapshot["loot"] = _snapshot_loot(unit)
            snapshot["experience_reward"] = unit.template_resource.experience_reward if unit.template_resource else 0
        snapshots.append(snapshot)
    return snapshots


## Copies reward candidates while the foe still exists. Only lootable belongings
## are recorded, with no runtime Node/Resource references. Eligibility and payout
## are separate settlement decisions; failed attempts never award these records.
func _snapshot_loot(unit: BattleUnit) -> Array[Dictionary]:
    var records: Array[Dictionary] = []
    if unit.inventory:
        for item: ItemBase in unit.inventory.slots.values():
            if item and item.template.lootable and item.count > 0:
                records.append(
                    {
                        "template_id": item.id,
                        "resource_path": item.template.resource_path,
                        "count": item.count,
                        "instance_id": item.instance_id
                    }
                )
    for child in unit.get_children():
        if child is UnitEquipmentSlot and child.equipped is Equipable:
            var item: Equipable = child.equipped
            if item.template.lootable:
                records.append(
                    {
                        "template_id": item.template.id,
                        "resource_path": item.template.resource_path,
                        "count": 1,
                        "instance_id": item.item_instance_id
                    }
                )
    return records


## Records the terminal side labels used by the two-team battle contract.
func _set_team_outcome(final_outcome: OUTCOME) -> void:
    winning_teams.clear()
    defeated_teams.clear()
    match final_outcome:
        OUTCOME.VICTORY:
            winning_teams.append(&"allies")
            defeated_teams.append(&"foes")
        OUTCOME.DEFEAT:
            winning_teams.append(&"foes")
            defeated_teams.append(&"allies")
