extends Node
## F6-only measurement, never a production battle route. Uses unchanged authored
## units, legal level-3 allocations and the existing debugging/balance runner.
## Basic Attack focus fire is a reproducible baseline, not a model of all tactics.

const CELINE := preload("res://GrimDaysBattle/resources/units/celine_teen/celine_battle_unit_template.tres")
## Authored courtyard variants exercised by the balance probe.
const ENCOUNTERS := [
    preload("res://GrimDaysVN/resources/events/2_0035_fight_harlok_alone.tres"),
    preload("res://GrimDaysVN/resources/events/2_0032_fight_harlok_and_goons.tres"),
]
## Legal attribute allocations compared across identical encounter seeds.
const PROFILES := {
    "unallocated": {},
    # Reference-inspired mixed investment, translated to the IMPLEMENTED budget.
    "mixed":
    {
        # Not a literal import of the spreadsheet's different progression totals.
        CombatStats.STATS.Vitality: 4,
        CombatStats.STATS.Finesse: 3,
        CombatStats.STATS.Mysticism: 3,
        CombatStats.STATS.Strength: 2,
        CombatStats.STATS.Perception: 2,
        CombatStats.STATS.Luck: 2
    },
    "physical": {CombatStats.STATS.Strength: 16},
    "evasion": {CombatStats.STATS.Finesse: 16},
    "resistance": {CombatStats.STATS.Endurance: 16},
    "split_defense": {CombatStats.STATS.Finesse: 8, CombatStats.STATS.Endurance: 8},
}
## Number of consecutive battle seeds tested per encounter/profile pair.
@export_range(1, 100) var samples: int = 8
## Round cap recorded as a censored draw rather than a victory.
@export_range(1, 200) var maximum_rounds: int = 100


class IsolatedParty:
    extends BattlePartyManager

    func _ready() -> void:
        pass


## Waits for the game manager if needed, then runs each encounter/profile/seed trial and its
## repeated-seed checks before printing the summaries.
func _ready() -> void:
    if not GameManager.is_node_ready():
        await GameManager.ready
    var rows: Array[Dictionary] = []
    for encounter: GameEventBattle in ENCOUNTERS:
        for profile: String in PROFILES:
            var trials: Array[Dictionary] = []
            for offset in samples:
                var trial := await _trial(encounter, PROFILES[profile], offset)
                trials.append(trial)
                if offset == 0:
                    assert(
                        trial == await _trial(encounter, PROFILES[profile], offset),
                        "A fresh seeded trial must reproduce the same outcomes and stats."
                    )
                await get_tree().process_frame
            rows.append(_summarize(encounter.id, profile, trials))
    for row in rows:
        CustomLogger.confirm(self, _ready, "COURTYARD_BALANCE: " + JSON.stringify(row), CustomLogger.LEVEL.IMPORTANT)
    CustomLogger.confirm(
        self, _ready, "COURTYARD_BALANCE_PROBE: COMPLETE (measurement, not acceptance)", CustomLogger.LEVEL.IMPORTANT
    )


## Every trial owns disposable units. No global party, authored Resource, save,
## reward settlement, story event or player's allocation is modified.
func _trial(encounter: GameEventBattle, allocation: Dictionary, seed_offset: int) -> Dictionary:
    var party := IsolatedParty.new()
    add_child(party)
    var ally := BattleUnit.create(CELINE)
    party.add_child(ally)
    party.runtime_units[CELINE.id] = ally
    party.active_party_ids = [CELINE.id]
    assert(party.ensure_minimum_level(CELINE.id, 3))
    if not allocation.is_empty():
        assert(party.spend_attribute_points(CELINE.id, allocation, party.get_attribute_points(CELINE.id).revision))
    var foes_holder := Node.new()
    add_child(foes_holder)
    var foes: Array[BattleUnit] = []
    for template: BattleUnitTemplate in encounter.foes:
        var foe := BattleUnit.create(template)
        foes_holder.add_child(foe)
        foes.append(foe)
    var starting_stats: Array[Dictionary] = [_stats(ally)]
    for foe in foes:
        starting_stats.append(_stats(foe))
    var runner := BattleHeadlessRunner.new()
    add_child(runner)
    var allies: Array[BattleUnit] = [ally]
    var result: BattleResult = await runner.run_battle(
        allies, foes, encounter.id, encounter.battle_seed + seed_offset, {}, maximum_rounds
    )
    assert(result.outcome != BattleResult.OUTCOME.ERROR, result.error)
    var hits := 0
    var misses := 0
    var damage := 0.0
    for event: BattleCombatEvent in result.combat_events:
        if event.actor != ally:
            continue
        if event.type == BattleCombatEvent.TYPE.HIT:
            hits += 1
        elif event.type == BattleCombatEvent.TYPE.MISS:
            misses += 1
        elif event.type == BattleCombatEvent.TYPE.DAMAGE:
            damage += event.amount
    var record := {
        "seed": result.battle_seed,
        "outcome": result.outcome,
        "rounds": result.rounds,
        "turns": result.turns,
        "hits": hits,
        "misses": misses,
        "damage": damage,
        "health_remaining": ally.get_stat(CombatStats.STATS.Health).Current,
        "starting_stats": starting_stats
    }
    for node in [runner, party, foes_holder]:
        node.queue_free()
        await node.tree_exited
    return record


## Returns selected combat values for one unit so the diagnostic can report each build.
func _stats(unit: BattleUnit) -> Dictionary:
    var values := {"unit": String(unit.template_resource.id)}
    for stat_id in [
        CombatStats.STATS.Level,
        CombatStats.STATS.Health,
        CombatStats.STATS.PhysicalDamage,
        CombatStats.STATS.Accuracy,
        CombatStats.STATS.Evasion,
        CombatStats.STATS.LuckyEvasion,
        CombatStats.STATS.CriticalStrike,
        CombatStats.STATS.PhysicalResistance,
        CombatStats.STATS.MagicResistance,
        CombatStats.STATS.Luck
    ]:
        values[CombatStats.get_stat_as_string(stat_id)] = unit.get_stat(stat_id).Current
    return values


## Report censored runs separately: a round-cap draw is NOT a 100-round victory.
func _summarize(encounter: StringName, profile: String, trials: Array[Dictionary]) -> Dictionary:
    var wins := 0
    var draws := 0
    var win_rounds: Array[int] = []
    var total_rounds := 0
    var hits := 0
    var misses := 0
    for trial in trials:
        total_rounds += trial.rounds
        hits += trial.hits
        misses += trial.misses
        if trial.outcome == BattleResult.OUTCOME.VICTORY:
            wins += 1
            win_rounds.append(trial.rounds)
        elif trial.outcome == BattleResult.OUTCOME.DRAW:
            draws += 1
    win_rounds.sort()
    return {
        "encounter": encounter,
        "profile": profile,
        "samples": trials.size(),
        "wins": wins,
        "defeats": trials.size() - wins - draws,
        "capped": draws,
        "mean_rounds_all": float(total_rounds) / trials.size(),
        "victory_rounds": win_rounds,
        "hits": hits,
        "misses": misses,
        "starting_stats": trials[0].starting_stats,
        "authored_seed_result": trials[0]
    }
