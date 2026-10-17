extends Object
## Defines action categories and centralizes target selection/validation rules.
class_name CombatActions

## Encounter turn commands; values remain compatible with existing command callers.
enum COMMAND { NONE = 0, DEFEND = 1, FLEE = 2, WAIT = 3 }

## Coarse AI-facing estimate of an action's tactical risk.
enum RISK_FACTOR { LOW = 0, MEDIUM = 1, HIGH = 2 }

## Semantic categories used by actions and their presentation.
enum TYPE {
    NONE = 0,
    PASSIVE = 1,
    BASIC = 2,
    SPECIAL = 3,
    PHYSICAL = 4,
    MAGICAL = 5,
    MIXED = 6,
    HEAL = 7,
    DEBUFF = 8,
    BUFF = 9,
    TRUE = 10
}
## Supported target-selection policies for actions and individual effects.
enum TARGET {
    SELF = 0,
    ALLY = 1,
    ALLIES = 2,
    FOE = 3,
    FOES = 4,
    OTHERS = 5,
    ALL = 6,
    RANDOM_FOE = 7,
    RANDOM_ALLY = 8,
    RANDOM_OTHER = 9,
    RANDOM_ALL = 10,
    ## The unit that was last successfuly hit by the 'owner' of the effect.
    LAST_HIT = 11,
    ## The unit that last successfully did damage to the 'owner' of the effect.
    LAST_DAMAGED_BY = 12,
    ## The action's selected target; appended to preserve serialized enum values.
    DEFAULT = 13,
}


## Resolves automatic targets for [param action]. Manual [constant TARGET.ALLY]
## and [constant TARGET.FOE] selection intentionally returns an empty list.
static func set_targets(action: Variant, unit: Variant) -> Dictionary:
    var targets: Array[BattleUnit]
    if not action or not is_instance_valid(unit):
        return {"targets": targets}
    if action is ActionTemplate and unit.has_madness():
        return {"targets": madness_targets(action, unit)}
    match action.target:
        TARGET.SELF:
            targets = [unit]
        TARGET.ALLIES:
            targets = get_participant_source(unit).get_unit_allies(unit)
        TARGET.FOES:
            targets = get_participant_source(unit).get_unit_foes(unit)
        TARGET.ALL:
            targets = get_participant_source(unit).get_all_active_units()
        TARGET.OTHERS:
            targets = get_participant_source(unit).get_all_active_units()
            targets.erase(unit)
        TARGET.RANDOM_ALL:
            _append_random(targets, get_participant_source(unit).get_all_active_units(), unit)
        TARGET.RANDOM_ALLY:
            _append_random(targets, get_participant_source(unit).get_unit_allies(unit), unit)
        TARGET.RANDOM_FOE:
            _append_random(targets, get_participant_source(unit).get_unit_foes(unit), unit)
        TARGET.RANDOM_OTHER:
            var all_units: Array[BattleUnit] = get_participant_source(unit).get_all_active_units()
            all_units.erase(unit)
            _append_random(targets, all_units, unit)
        TARGET.LAST_DAMAGED_BY:
            if is_instance_valid(unit.last_hit_by):
                targets = [unit.last_hit_by]
        TARGET.LAST_HIT:
            if is_instance_valid(unit.last_target):
                targets = [unit.last_target]

    return {"targets": targets}


## Appends one candidate chosen through the acting unit's seeded RNG when available.
static func _append_random(
    destination: Array[BattleUnit],
    candidates: Array[BattleUnit],
    unit: BattleUnit,
) -> void:
    if candidates.is_empty():
        return
    var selected: Variant = (
        unit.randomizer.pick_random(candidates) if unit and unit.randomizer else candidates.pick_random()
    )
    if selected:
        destination.append(selected)


## Returns whether [param candidate] is active and satisfies the action's team policy.
static func valid_target(
    action: ActionTemplate, active: BattleUnit, candidate: BattleUnit, madness: bool = false
) -> bool:
    if not action or not active or not is_instance_valid(candidate):
        return false
    var source = get_participant_source(active)
    if source is BattleEncounterRoster and not source.is_present(candidate):
        return false
    var health := candidate.get_stat(CombatStats.STATS.Health)
    if not health or health.Current <= 0.0:
        return false
    if action is BattleMadnessAction:
        return candidate == active
    if madness or active.has_madness():
        return candidate in get_participant_source(active).get_all_active_units()
    var same_party: bool = active.get_parent() == candidate.get_parent()
    if not active.team_id.is_empty() and not candidate.team_id.is_empty():
        same_party = active.team_id == candidate.team_id
    match action.target:
        TARGET.SELF:
            return candidate == active
        TARGET.ALLY:
            return same_party and (candidate != active or action.include_self)
        TARGET.ALLIES, TARGET.RANDOM_ALLY:
            return same_party and candidate != active
        TARGET.FOE, TARGET.FOES, TARGET.RANDOM_FOE:
            return not same_party
        TARGET.OTHERS, TARGET.RANDOM_OTHER:
            return candidate != active
        TARGET.ALL, TARGET.RANDOM_ALL:
            return true
        TARGET.LAST_HIT:
            return candidate == active.last_target
        TARGET.LAST_DAMAGED_BY:
            return candidate == active.last_hit_by
    return false


## Expands one effect's target policy relative to its actor and selected action target.
static func get_effect_target(
    active: BattleUnit, target: BattleUnit, action_effect: EffectTemplate, madness: bool = false
) -> Array[BattleUnit]:
    var effect_targets: Array[BattleUnit]
    if not is_instance_valid(active) or not action_effect:
        return effect_targets
    if madness and not action_effect is EffectSpawnParticlesTemplate:
        if action_effect.target in [TARGET.ALLIES, TARGET.FOES]:
            return _madness_team(active, target)
        if action_effect.target in [TARGET.ALL, TARGET.OTHERS]:
            return get_participant_source(active).get_all_active_units()
        if is_instance_valid(target):
            effect_targets.append(target)
        return effect_targets
    match action_effect.target:
        TARGET.SELF:
            effect_targets = [active]
        TARGET.DEFAULT, TARGET.ALLY:
            effect_targets = [target]
        TARGET.FOE:
            effect_targets = [target]
        TARGET.LAST_HIT:
            effect_targets = [active.last_target]
        TARGET.LAST_DAMAGED_BY:
            effect_targets = [active.last_hit_by]
        TARGET.ALLIES:
            effect_targets = get_participant_source(active).get_unit_allies(active)
        TARGET.FOES:
            effect_targets = get_participant_source(active).get_unit_foes(active)
        TARGET.ALL:
            effect_targets = get_participant_source(active).get_all_active_units()
        TARGET.OTHERS:
            var all_units = get_participant_source(active).get_all_active_units()
            all_units.erase(active)
            effect_targets = all_units
        TARGET.RANDOM_ALL:
            _append_random(effect_targets, get_participant_source(active).get_all_active_units(), active)
        TARGET.RANDOM_ALLY:
            _append_random(effect_targets, get_participant_source(active).get_unit_allies(active), active)
        TARGET.RANDOM_FOE:
            _append_random(effect_targets, get_participant_source(active).get_unit_foes(active), active)
        TARGET.RANDOM_OTHER:
            var all_units: Array[BattleUnit] = get_participant_source(active).get_all_active_units()
            all_units.erase(active)
            _append_random(effect_targets, all_units, active)
    for index in range(effect_targets.size() - 1, -1, -1):
        if (
            not is_instance_valid(effect_targets[index])
            or (
                get_participant_source(active) is BattleEncounterRoster
                and not get_participant_source(active).is_present(effect_targets[index])
            )
        ):
            effect_targets.remove_at(index)
    return effect_targets


## Units deployed by a production roster never query the debug battle holders.
static func get_participant_source(unit: BattleUnit) -> Node:
    return unit.participant_source if is_instance_valid(unit.participant_source) else BattleController


## Random selection ignores allegiance and self restrictions, never roster/liveness.
## Whole-team actions roll one participant first, then include that participant's team.
static func madness_targets(action: ActionTemplate, actor: BattleUnit) -> Array[BattleUnit]:
    var targets: Array[BattleUnit] = []
    if action is BattleMadnessAction:
        targets.append(actor)
        return targets
    var candidates: Array[BattleUnit] = get_participant_source(actor).get_all_active_units().duplicate()
    if candidates.is_empty():
        return targets
    if action.target in [TARGET.ALL, TARGET.OTHERS]:
        return candidates
    if action.target in [TARGET.ALLIES, TARGET.FOES]:
        var first: BattleUnit = actor.randomizer.pick_random(candidates)
        return _madness_team(actor, first)
    while not candidates.is_empty() and targets.size() < maxi(action.target_amount, 1):
        var chosen: BattleUnit = actor.randomizer.pick_random(candidates)
        targets.append(chosen)
        candidates.erase(chosen)
    return targets


## Keep the rolled unit first; team overrides affect targeting but not victory membership.
static func _madness_team(actor: BattleUnit, first: BattleUnit) -> Array[BattleUnit]:
    var targets: Array[BattleUnit] = []
    if not is_instance_valid(first) or not first.is_active:
        return targets
    targets.append(first)
    for candidate: BattleUnit in get_participant_source(actor).get_all_active_units():
        var same_team: bool = (
            candidate.team_id == first.team_id
            if not first.team_id.is_empty()
            else candidate.get_parent() == first.get_parent()
        )
        if candidate != first and same_team:
            targets.append(candidate)
    return targets


## Group selection never fabricates individual TARGETED responses for its members.
static func is_group_target(mode: TARGET) -> bool:
    return mode in [TARGET.ALLIES, TARGET.FOES, TARGET.ALL, TARGET.OTHERS]
