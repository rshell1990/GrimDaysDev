extends Node
## Tracks the player's existing allies and creates opponents for this battle.
## Only opponents belong to this node; allies remain with the party manager.
class_name BattleEncounterRoster

## Script loaded for template validator; reused instead of looking up the file on each call.
const TEMPLATE_VALIDATOR := preload(
    "res://GrimDaysBattle/scripts/Unit/Resources/battle_unit_template_validator.gd"
)

## Existing party allies in their starting order, even if an effect temporarily changes their team.
var _allies: Array[BattleUnit] = []
## Opponents created for this battle in their starting order, even if their team temporarily
## changes.
var _foes: Array[BattleUnit] = []
## Stores each ally's original team, player-control setting and source of nearby units, for later
## restoration.
var _ally_defaults: Dictionary = {}
## Whether allies and opponents have been set up for a battle.
var _deployed: bool = false
## Party manager reserved for this battle until cleanup, preventing another battle from using it.
var _party: BattlePartyManager
## Reason the most recent unit setup failed; cleared when a new setup begins.
var last_error: String = ""
## Current attempt's guarded turn-order command, injected by the coordinator.
var turn_delay_request: Callable
## Absent participants remain alive and retain effect-source identity.
var escaped: Dictionary = {}
signal unit_escaped(unit: BattleUnit)


func is_present(unit: BattleUnit) -> bool:
    return unit in get_participants() and not escaped.has(unit)


func escape(unit: BattleUnit) -> void:
    if unit in _allies and not escaped.has(unit):
        escaped[unit] = true
        unit_escaped.emit(unit)


## Checks the party and opponent templates before changing any allies.
## Reserves the existing party and creates the opponents; returns false if setup fails.
func deploy(party: BattlePartyManager, foe_templates: Array[BattleUnitTemplate]) -> bool:
    last_error = ""
    if _deployed or not is_inside_tree():
        return _reject("The encounter roster must be in the tree and unoccupied.")
    if not is_instance_valid(party) or not party.is_inside_tree():
        return _reject("A live runtime party manager is required.")
    var allies := party.get_active_party()
    if allies.is_empty() or foe_templates.is_empty():
        return _reject("An encounter requires an active runtime party and opponents.")
    for ally in allies:
        if not is_instance_valid(ally) or ally.is_queued_for_deletion() or ally.get_parent() != party:
            return _reject("Permanent allies must remain under their runtime party manager.")
    for template in foe_templates:
        var errors: PackedStringArray = TEMPLATE_VALIDATOR.validate(template)
        if not errors.is_empty():
            return _reject("Invalid opponent: %s" % "; ".join(errors))
    if not party.acquire_encounter(self):
        return _reject("The runtime party is already participating in another encounter.")
    _party = party
    # Construct every opponent before changing ally affiliation or control.
    for template in foe_templates:
        var foe := BattleUnit.create(template)
        if not foe:
            for created in _foes:
                created.free()
            _foes.clear()
            _party.release_encounter(self)
            _party = null
            return _reject("Could not construct an encounter opponent.")
        _foes.append(foe)
    _allies.assign(allies)
    _deployed = true
    for ally in _allies:
        _ally_defaults[ally] = {
            "team": ally.get_base_team_id(),
            "player_controlled": ally.get_base_player_controlled(),
            "participant_source": ally.participant_source,
        }
        # Base assignments preserve any existing source-owned overrides.
        ally.team_id = &"allies"
        ally.player_controlled = true
        ally.participant_source = self
    for foe in _foes:
        foe.team_id = &"foes"
        foe.player_controlled = false
        foe.participant_source = self
        add_child(foe)
    return true


## Membership stays fixed even when an effect temporarily changes a team.
func get_allies() -> Array[BattleUnit]:
    return _allies.duplicate()


## Returns a new list of the original opponents. Editing the list does not change this roster, but
## the units themselves are the same objects.
func get_foes() -> Array[BattleUnit]:
    return _foes.duplicate()


## Returns a new list of all allies followed by all opponents, including defeated units.
func get_participants() -> Array[BattleUnit]:
    return _allies + _foes


## Returns units that still exist, can fight, and currently belong to the requested team.
func get_active_team(team_id: StringName) -> Array[BattleUnit]:
    var members: Array[BattleUnit] = []
    for unit in get_participants():
        if is_instance_valid(unit) and unit.is_active and is_present(unit) and unit.team_id == team_id:
            members.append(unit)
    return members


## Removes effects marked to last only for this battle from all units that still exist, including
## defeated units.
func remove_battle_effects() -> void:
    for unit in get_participants():
        if is_instance_valid(unit) and unit.effect_manager:
            unit.clear_cowering()
            unit.effect_manager.remove_battle_scoped_effects()


## Returns units that still exist and can fight, in their original starting order.
func get_all_active_units() -> Array[BattleUnit]:
    var units: Array[BattleUnit] = []
    for unit in get_participants():
        if is_instance_valid(unit) and unit.is_active and is_present(unit):
            units.append(unit)
    return units


## Returns other active participants sharing the unit's current team.
func get_unit_allies(unit: BattleUnit) -> Array[BattleUnit]:
    return _related_units(unit, true)


## Returns other active participants whose current team differs from the unit's.
func get_unit_foes(unit: BattleUnit) -> Array[BattleUnit]:
    return _related_units(unit, false)


## Returns other units that can fight, choosing either the same team or other teams as requested.
func _related_units(unit: BattleUnit, same_team: bool) -> Array[BattleUnit]:
    var units: Array[BattleUnit] = []
    for candidate in get_all_active_units():
        if candidate != unit and (candidate.team_id == unit.team_id) == same_team:
            units.append(candidate)
    return units


## Removes battle effects, restores allies' original settings, and deletes opponents.
## Safe to call more than once; allies stay with their party manager.
func release() -> void:
    turn_delay_request = Callable()
    escaped.clear()
    remove_battle_effects()
    for ally in _allies:
        if not is_instance_valid(ally):
            continue
        var defaults: Dictionary = _ally_defaults[ally]
        ally.team_id = defaults.team
        ally.player_controlled = defaults.player_controlled
        ally.participant_source = defaults.participant_source
        ally.last_hit_by = null
        ally.last_target = null
    for foe in _foes:
        if is_instance_valid(foe) and not foe.is_queued_for_deletion():
            foe.queue_free()
    _allies.clear()
    _foes.clear()
    _ally_defaults.clear()
    _deployed = false
    if is_instance_valid(_party):
        _party.release_encounter(self)
    _party = null


## Effects may only mutate this deployed roster's current pending turns.
func delay_pending_turn(unit: BattleUnit) -> bool:
    return _deployed and turn_delay_request.is_valid() and turn_delay_request.call(unit)


## When this node leaves the scene, cleans up opponents and lets the party enter another battle.
func _exit_tree() -> void:
    release()


## Stores the reason unit setup failed and returns false.
func _reject(message: String) -> bool:
    last_error = message
    return false
