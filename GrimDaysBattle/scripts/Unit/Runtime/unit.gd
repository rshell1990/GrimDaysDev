# lint:ignore file-length -- Keep the unit lifecycle and save-state API together.
# Editor configuration for BattleUnit.
@icon("res://GrimDays/assets/visuals/class_icons/brutal-helm.svg")
extends Node
#region BATTLE UNIT
## The generic class for a 'unit' used in battle, it represents and is ued to manage the backend state of a combatant.
##
##
class_name BattleUnit
#endregion

## Emitted when effects triggered.
signal attribute_points_changed

## Persistent earned-level watermark and purchased attributes; no UI drafts.
var attribute_progression: Dictionary = {}
## Suppresses progression synchronization during coordinated state restoration.
var attribute_progression_suspended: bool = false
## Prevents recursive progression updates caused by modifier signals.
var attribute_progression_busy: bool = false

## Announces completion of an effect-trigger request using its request ID.
signal effects_triggered(request_id: StringName)
## Emitted when basic action changed.
signal basic_action_changed(action: ActionTemplate)
## Emitted when action rank changed.
signal action_rank_changed(action: ActionTemplate, rank: int)
## Emitted when control changed.
signal control_changed(player_has_control: bool)
## Emitted when team changed.
signal team_changed(team_id: StringName)
## Emitted when battle sprite changed.
signal battle_sprite_changed(sprite_scene: PackedScene)
## One completed resource-effect operation, before effect completion or legacy feedback.
## Encounter-local recorders observe this; it never drives combat progression.
signal resource_operation_resolved(report: Dictionary)
## Successful non-resource turn-order operation, observed by combat-event capture.
signal turn_order_operation_resolved(report: Dictionary)
## One immediate action damage operation's hit/miss, before critical and damage.
signal damage_hit_resolved(report: Dictionary)
## Hostile selection before target reactions, distinct from incoming damage.
signal action_targeted(report: Dictionary)
## Reports a completed target replacement for history and optional presentation.
signal action_substituted(report: Dictionary)

#region PROPERTIES
## Presents the level stored in the level controlling component of a unit.
var level:
    get:
        return get_stat(CombatStats.STATS.Level).Current
## The original template resource used to create this unit.
var template_resource: BattleUnitTemplate:
    get:
        return template_resource
    set(value):
        template_resource = value
        if not value:
            if is_node_ready():
                _synchronize_intrinsic_effects()
            return
        name = value.id
        default_basic_action_template = value.basic_action_template
        default_battle_sprite = value.battle_sprite
        if is_node_ready():
            _synchronize_intrinsic_effects()
## Per-life completion markers prevent production/legacy handoffs replaying lethal responses.
var defeat_resolved: bool
var kill_resolved: bool
## Property to indicate if the unit is still capable of combat.
var is_active: bool:
    get:
        return get_stat(CombatStats.STATS.Health).Current > 0
## Practical action capacity: effective Swiftness reduced by Encumberance.
## Keeps the existing integer rounding and minimum speed of 1; this is not a separate stat.
var speed: float:
    get:
        var swiftness: float = get_stat(CombatStats.STATS.Swiftness).Current
        var current_encumberance: float = get_stat(CombatStats.STATS.Encumberance).Current / 100.0
        var half_swiftness: float = snappedf(swiftness * 0.5, 1.0)

        return maxf(snappedf(swiftness - (half_swiftness * current_encumberance), 1.0), 1.0)
#endregion

#endregion
#region VARIABLES
## The identifier that information about this unit will use when the game is saved.
var save_name: String = "unit"
## Handles all effects currently applied to a unit.
var effect_manager: EffectsManager
## Items available to this combatant. The party stash is not a combat fallback.
## Carried items do not grant effects or weight; only directly equipped items do.
var inventory: Inventory
## Handles everything to do with chance.
var randomizer: UnitRandomizationControl
## Indicates a guarantee that the next attack will hit.
var next_attack_hits: bool
## The unit that last dealt damage to this unit's health stat.
var last_hit_by: Node
## The unit last targeted by this unit.
var last_target: Node
## Injected encounter roster. Legacy/debug units use the global controller.
var participant_source: Node
## Optional encounter-local cosmetic dispatcher: (kind, payload) -> accepted.
## A non-null callback selects production routing even if it has become invalid;
## stale requests must never fall back into the debug controller's displays.
var presentation_request: Callable
## Whether the base player controlled condition currently holds.
var _base_player_controlled: bool
## Lookup table that stores control overrides for deterministic runtime access.
var _control_overrides: Dictionary
## Ordered runtime collection of control override order.
var _control_override_order: Array[int]
## Effective controller. Assignments set the base value; effects add source-keyed overrides.
var player_controlled: bool:
    get:
        if get_forced_action_effect():
            return false
        if has_madness():
            return false
        if not _control_override_order.is_empty():
            return _control_overrides[_control_override_order.back()]
        return _base_player_controlled
    set(value):
        _base_player_controlled = value
        control_changed.emit(player_controlled)
## Runtime base team id state used by this unit.
var _base_team_id: StringName
## Lookup table that stores team overrides for deterministic runtime access.
var _team_overrides: Dictionary
## Ordered runtime collection of team override order.
var _team_override_order: Array[int]
## Effective affiliation, independent from the unit's presentation/tree parent.
var team_id: StringName:
    get:
        if not _team_override_order.is_empty():
            return _team_overrides[_team_override_order.back()]
        return _base_team_id
    set(value):
        _base_team_id = value
        team_changed.emit(team_id)
##  A collection of all stats referenced by the stat names.
var stat_dictionary: Dictionary[StringName,UnitGenericStat]
## Unit-owned project skill state. Null only for templates awaiting migration.
var skills: BattleUnitSkills
## The unit template's action, restored whenever no weapon override is active.
var default_basic_action_template: ActionTemplate
## Source-keyed weapon overrides in equip order. The most recently equipped
## weapon owns the active Basic Attack.
var _basic_action_overrides: Dictionary[int,ActionTemplate]
## Ordered runtime collection of basic action override order.
var _basic_action_override_order: Array[int]
## Source-keyed appearance overrides use the same newest-grant-wins policy as
## control, team, and weapon overrides.
var default_battle_sprite: PackedScene
## Lookup table that stores battle sprite overrides for deterministic runtime access.
var _battle_sprite_overrides: Dictionary[int,PackedScene]
## Ordered runtime collection of battle sprite override order.
var _battle_sprite_override_order: Array[int]
## Learned action resources and their unit-owned ranks, keyed by stable action ID.
var _owned_actions: Dictionary[StringName,ActionTemplate]
## Lookup table that stores action ranks for deterministic runtime access.
var _action_ranks: Dictionary[StringName,int]
## Stable grant source -> { action, rank }. Effective ownership is the highest
## rank currently provided for each action ID.
var _action_grants_by_source: Dictionary[StringName,Dictionary]
## Stored as authored cooldown + 1 so the cooldown begins on the next turn.
var _action_cooldowns: Dictionary[StringName,int]
## Monotonic serial that distinguishes effect requests made by this unit.
var _effect_request_serial: int
## Active source used to reconcile effects authored directly on the unit template.
var _intrinsic_effect_source_id: StringName
#endregion


#region SIGNAL RESPONSES
## Method to connect a remote signal to this unit.
func listen_for(sent_signal: Signal, sent_callable: Callable) -> void:
    if sent_signal.is_connected(sent_callable):
        sent_signal.disconnect(sent_callable)

    sent_signal.connect(sent_callable)


## When effects finished triggering by the unit's EffectManager, then signals effects have been triggered.
func after_effects_triggered(request_id: StringName) -> void:
    effects_triggered.emit(request_id)


## Add an effect ot the unit.
func add_effect(sender: Node, target: Node, effect: EffectTemplate, context: Dictionary = {}) -> EffectBase:
    if self != target:
        return null
    if not effect_manager:
        effect_manager = get_meta(EFFECTS_MANAGER_NAME)

    return effect_manager.add_effect(sender, target, effect, context)


#endregion


##
## Returns action rank for this unit.
func get_action_rank(action: ActionTemplate, use_grant_rank: bool = false) -> int:
    var forced := get_forced_action_effect()
    if forced and action == forced.definition.action:
        return forced.definition.action_rank
    if not action:
        return 0
    if action is BattleItemAction:
        return 1 if action.get_rank_template(1) else 0
    # A generated chain is an immutable snapshot; stale callbacks cannot execute it.
    if action.has_meta(&"project_skill_compiled") and _owned_actions.get(action.id) != action:
        return 0
    # Basic/special/equipment overrides select rank one by resource identity, even
    # when a learned source with the same ID owns a higher rank. Automatic Lucidity
    # outcomes explicitly select their temporary/learned grant instead.
    if (
        not use_grant_rank
        and (action == get_basic_action() or (template_resource and action == template_resource.special_action))
    ):
        return 1 if action.get_rank_template(1) else 0
    return _action_ranks.get(action.id, 0)


## Adds ownership of action for this unit.
func learn_action(action: ActionTemplate, rank: int = 1) -> bool:
    if not action:
        return false
    return grant_action_from_source(StringName("learned:%s" % action.id), action, rank)


## Grants action from source for this unit.
func grant_action_from_source(source_id: StringName, action: ActionTemplate, rank: int = 1) -> bool:
    if source_id.is_empty() or not action or action.id.is_empty():
        return false
    var owned_rank := _clamp_action_rank(action, rank)
    if owned_rank < 1:
        return false
    var previous_action: ActionTemplate = null
    if _action_grants_by_source.has(source_id):
        previous_action = _action_grants_by_source[source_id].get("action")
    _action_grants_by_source[source_id] = {"action": action, "rank": owned_rank}
    if previous_action and previous_action.id != action.id:
        _refresh_action_grants(previous_action.id)
    _refresh_action_grants(action.id)
    return true


## Reverses action source for this unit.
func revoke_action_source(source_id: StringName) -> void:
    if not _action_grants_by_source.has(source_id):
        return
    var action: ActionTemplate = _action_grants_by_source[source_id].get("action")
    _action_grants_by_source.erase(source_id)
    if action:
        _refresh_action_grants(action.id)


## Removes ownership of action for this unit.
func forget_action(action: ActionTemplate) -> void:
    if not action:
        return
    for source_id in _action_grants_by_source.keys():
        var grant_action: ActionTemplate = _action_grants_by_source[source_id].get("action")
        if grant_action and grant_action.id == action.id:
            _action_grants_by_source.erase(source_id)
    _refresh_action_grants(action.id)


## Returns whether unit owns action.
func owns_action(action: ActionTemplate) -> bool:
    return get_action_rank(action) > 0


## Returns whether action learned.
func is_action_learned(action: ActionTemplate) -> bool:
    return action != null and _owned_actions.has(action.id)


## Returns owned actions for this unit.
func get_owned_actions() -> Array[ActionTemplate]:
    var actions: Array[ActionTemplate]
    var basic_action := get_basic_action()
    if basic_action:
        actions.append(basic_action)
    if template_resource.special_action and template_resource.special_action != basic_action:
        actions.append(template_resource.special_action)
    for action in _owned_actions.values():
        if not basic_action or action.id != basic_action.id:
            actions.append(action)
    return actions


## Returns action cooldown for this unit.
func get_action_cooldown(action: ActionTemplate) -> int:
    if not action or action is BattleItemAction:
        return 0
    return maxi(_action_cooldowns.get(action.id, 0), 0)


## Returns save-safe action ownership state. Resource paths are used instead of
## serializing live Resource instances so reconstructed units receive the
## canonical authored ActionTemplate.
func serialize_action_state() -> Dictionary:
    var action_grants: Array[Dictionary] = []
    var source_ids: Array = _action_grants_by_source.keys()
    source_ids.sort()
    for source_id_value in source_ids:
        var source_id := StringName(source_id_value)
        # Derived tree grants are reconstructed from investment, never saved as
        # generated Resource paths. Project-owned save integration follows separately.
        if String(source_id).begins_with("skill_tree:") or String(source_id).begins_with("project_skill:"):
            continue
        var grant: Dictionary = _action_grants_by_source[source_id]
        var action: ActionTemplate = grant.get("action")
        if not action or action.resource_path.is_empty():
            (
                CustomLogger
                . warn(
                    self,
                    serialize_action_state,
                    "Cannot persist learned action %s without a resource path." % (action.id if action else &""),
                    CustomLogger.LEVEL.IMPORTANT,
                )
            )
            continue
        (
            action_grants
            . append(
                {
                    "source_id": source_id,
                    "id": action.id,
                    "resource_path": action.resource_path,
                    "rank": int(grant.get("rank", 1)),
                }
            )
        )
    var cooldowns: Dictionary = {}
    for action_id in _action_cooldowns:
        var remaining: int = maxi(_action_cooldowns[action_id], 0)
        if remaining > 0:
            cooldowns[action_id] = remaining
    return {"action_grants": action_grants, "cooldowns": cooldowns}


## Restores action state for this unit.
func restore_action_state(data: Dictionary, restore_cooldowns: bool = true) -> void:
    _owned_actions.clear()
    _action_ranks.clear()
    _action_grants_by_source.clear()
    _action_cooldowns.clear()
    var saved_grants: Array = data.get("action_grants", data.get("learned_actions", []))
    for saved_action in saved_grants:
        if saved_action is not Dictionary:
            continue
        var resource_path: String = saved_action.get("resource_path", "")
        if resource_path.is_empty() or not ResourceLoader.exists(resource_path):
            (
                CustomLogger
                . warn(
                    self,
                    restore_action_state,
                    "Skipping missing learned action resource: %s" % resource_path,
                    CustomLogger.LEVEL.IMPORTANT,
                )
            )
            continue
        var action = ResourceLoader.load(resource_path)
        var expected_id := StringName(saved_action.get("id", &""))
        if action is not ActionTemplate or action.id != expected_id:
            (
                CustomLogger
                . warn(
                    self,
                    restore_action_state,
                    "Skipping learned action whose resource does not match %s." % expected_id,
                    CustomLogger.LEVEL.IMPORTANT,
                )
            )
            continue
        var source_id := StringName(saved_action.get("source_id", "learned:%s" % action.id))
        if String(source_id).begins_with(BattleSkillChainResolver.SOURCE_PREFIX):
            continue  # Generated ownership is restored only from the investment ledger.
        grant_action_from_source(source_id, action, int(saved_action.get("rank", 1)))
    if restore_cooldowns:
        restore_action_cooldowns(data.get("cooldowns", {}))


## Apply only after every ownership source (including project skill grants) is rebuilt.
func restore_action_cooldowns(saved_cooldowns: Dictionary) -> void:
    _action_cooldowns.clear()
    for saved_id in saved_cooldowns:
        var action_id := StringName(saved_id)
        if not _get_action_by_id(action_id) and not (skills and skills.owns_chain(action_id)):
            continue
        var remaining: int = maxi(int(saved_cooldowns[saved_id]), 0)
        if remaining > 0:
            _action_cooldowns[action_id] = remaining


## Returns action by id for this unit.
func _get_action_by_id(action_id: StringName) -> ActionTemplate:
    var basic_action := get_basic_action()
    if basic_action and basic_action.id == action_id:
        return basic_action
    return _owned_actions.get(action_id)


## Recomputes action grants for this unit.
func _refresh_action_grants(action_id: StringName) -> void:
    var best_action: ActionTemplate = null
    var best_rank: int = 0
    for grant in _action_grants_by_source.values():
        var action: ActionTemplate = grant.get("action")
        if not action or action.id != action_id:
            continue
        var rank: int = int(grant.get("rank", 0))
        if rank > best_rank:
            best_action = action
            best_rank = rank
    if not best_action:
        var removed_action: ActionTemplate = _owned_actions.get(action_id)
        _owned_actions.erase(action_id)
        _action_ranks.erase(action_id)
        _action_cooldowns.erase(action_id)
        if removed_action:
            action_rank_changed.emit(removed_action, 0)
        return
    _owned_actions[action_id] = best_action
    _action_ranks[action_id] = best_rank
    action_rank_changed.emit(best_action, best_rank)


## Returns whether the current source can select/commit this action.
func can_use_action(action: ActionTemplate, require_valid_target: bool = false) -> bool:
    return get_action_unavailable_reason(action, require_valid_target).is_empty()


## One selection policy supplies actionable reasons to player UI and AI eligibility.
func get_action_unavailable_reason(action: ActionTemplate, require_valid_target: bool = false) -> String:
    if is_stunned():
        return "Stunned units cannot act."
    if action:
        var equipment_reason := action.get_equipment_unavailable_reason(self)
        if not equipment_reason.is_empty():
            return equipment_reason
    var forced := get_forced_action_effect()
    if forced and action == forced.definition.action:
        if not action.get_rank_template(forced.definition.action_rank):
            return "The forced action rank is unavailable."
        if is_action_disabled_by_effects(action):
            return "An active effect prevents this action."
        return "No valid targets." if require_valid_target and not has_valid_target_for(action) else ""
    if not action:
        return "No action assigned."
    if is_action_disabled_by_effects(action):
        return "An active effect prevents this action."
    if action is BattleMadnessAction:
        return "" if action.can_use(self) else "This response is not currently available."
    if action is BattleItemAction:
        if not action.can_use(self):
            return "This item is no longer available."
    else:
        if not owns_action(action):
            return "This action is no longer granted."
        if _action_cooldowns.get(action.id, 0) > 0:
            return "This action is on cooldown."
        var rank_template := _get_owned_rank_template(action)
        if not rank_template:
            return "The selected rank is unavailable."
        for stat_id in rank_template.cost:
            var amount: int = rank_template.cost[stat_id]
            var stat := get_stat(stat_id)
            if amount < 0 or not stat:
                return "The action has an invalid resource cost."
            if stat.Current < amount:
                return "Requires %s %s." % [amount, CombatStats.get_stat_as_string(stat_id)]
    if require_valid_target and not has_valid_target_for(action):
        return "No valid targets."
    return ""


## Validates and pays action cost for this unit.
func pay_action_cost(action: ActionTemplate) -> bool:
    if not action or is_action_disabled_by_effects(action):
        return false
    if action is BattleMadnessAction:
        return can_use_action(action)
    if action is BattleItemAction:
        return action.consume(self)
    if not can_use_action(action):
        return false
    var rank_template := _get_owned_rank_template(action)
    for stat_id in rank_template.cost:
        get_stat(stat_id).decrease_current_flat(rank_template.cost[stat_id])
    if rank_template.cooldown_turns > 0:
        _action_cooldowns[action.id] = rank_template.cooldown_turns + 1
    return true


## Handles the turn started notification for this unit.
func on_turn_started() -> void:
    clear_cowering()
    for action_id in _action_cooldowns.keys():
        _action_cooldowns[action_id] -= 1
        if _action_cooldowns[action_id] <= 0:
            _action_cooldowns.erase(action_id)


## Chooses action for ai for this unit.
func choose_action_for_ai() -> ActionTemplate:
    var actions := get_ai_actions()
    return (
        randomizer.pick_random(actions)
        if has_madness() and not actions.is_empty()
        else (actions[0] if not actions.is_empty() else null)
    )


## Returns whether valid target for.
func has_valid_target_for(action: ActionTemplate) -> bool:
    var validate_target: Callable = CombatActions.valid_target
    for candidate in CombatActions.get_participant_source(self).get_all_active_units():
        if validate_target.call(action, self, candidate):
            return true
    return false


## Returns owned rank template for this unit.
func _get_owned_rank_template(action: ActionTemplate) -> RankTemplate:
    if not action:
        return null
    return action.get_rank_template(get_action_rank(action))


## Clamps action rank for this unit.
func _clamp_action_rank(action: ActionTemplate, rank: int) -> int:
    if action.get_rank_count() < 1:
        return 0
    var number := clampi(rank, 1, action.get_rank_count())
    if action.ranks.generated and not action.get_rank_template(number):
        return 0
    return number


## Returns basic action for this unit.
func get_basic_action() -> ActionTemplate:
    if not _basic_action_override_order.is_empty():
        return _basic_action_overrides[_basic_action_override_order.back()]
    return default_basic_action_template


## Adds basic action override for this unit.
func add_basic_action_override(source: Node, action: ActionTemplate) -> void:
    if not source or not action:
        return
    var source_id := source.get_instance_id()
    _basic_action_overrides[source_id] = action
    _basic_action_override_order.erase(source_id)
    _basic_action_override_order.append(source_id)
    basic_action_changed.emit(get_basic_action())


## Removes basic action override for this unit.
func remove_basic_action_override(source: Node) -> void:
    if not source:
        return
    var source_id := source.get_instance_id()
    if not _basic_action_overrides.erase(source_id):
        return
    _basic_action_override_order.erase(source_id)
    basic_action_changed.emit(get_basic_action())


## Returns battle sprite for this unit.
func get_battle_sprite() -> PackedScene:
    if not _battle_sprite_override_order.is_empty():
        return _battle_sprite_overrides[_battle_sprite_override_order.back()]
    return default_battle_sprite


## Adds battle sprite override for this unit.
func add_battle_sprite_override(source: Object, sprite_scene: PackedScene) -> void:
    if not source or not sprite_scene:
        return
    var source_id := source.get_instance_id()
    _battle_sprite_overrides[source_id] = sprite_scene
    _battle_sprite_override_order.erase(source_id)
    _battle_sprite_override_order.append(source_id)
    battle_sprite_changed.emit(get_battle_sprite())


## Removes battle sprite override for this unit.
func remove_battle_sprite_override(source: Object) -> void:
    if not source:
        return
    var source_id := source.get_instance_id()
    if not _battle_sprite_overrides.erase(source_id):
        return
    _battle_sprite_override_order.erase(source_id)
    battle_sprite_changed.emit(get_battle_sprite())


## Base controller excludes temporary source-owned overrides.
func get_base_player_controlled() -> bool:
    return _base_player_controlled


## Base affiliation excludes temporary source-owned overrides.
func get_base_team_id() -> StringName:
    return _base_team_id


## Adds control override for this unit.
func add_control_override(source: Object, value: bool) -> void:
    if not source:
        return
    var source_id := source.get_instance_id()
    _control_overrides[source_id] = value
    _control_override_order.erase(source_id)
    _control_override_order.append(source_id)
    control_changed.emit(player_controlled)


## Removes control override for this unit.
func remove_control_override(source: Object) -> void:
    if not source:
        return
    var source_id := source.get_instance_id()
    if not _control_overrides.erase(source_id):
        return
    _control_override_order.erase(source_id)
    control_changed.emit(player_controlled)


## Adds team override for this unit.
func add_team_override(source: Object, value: StringName) -> void:
    if not source or value.is_empty():
        return
    var source_id := source.get_instance_id()
    _team_overrides[source_id] = value
    _team_override_order.erase(source_id)
    _team_override_order.append(source_id)
    team_changed.emit(team_id)


## Removes team override for this unit.
func remove_team_override(source: Object) -> void:
    if not source:
        return
    var source_id := source.get_instance_id()
    if not _team_overrides.erase(source_id):
        return
    _team_override_order.erase(source_id)
    team_changed.emit(team_id)


## Returns equipment slot for this unit.
func get_equipment_slot(slot: UnitEquipmentSlot.SLOT) -> UnitEquipmentSlot:
    return get_meta(UnitEquipmentSlot.TYPES[slot], null) as UnitEquipmentSlot


## Equips item for this unit.
func equip_item(template: EquipmentTemplate, slot: UnitEquipmentSlot.SLOT) -> Equipable:
    var equipment_slot := get_equipment_slot(slot)
    if not equipment_slot:
        return null
    var equip_callable: Callable = equipment_slot.equip
    return await equip_callable.call(self, template)


## Unequips item for this unit.
func unequip_item(slot: UnitEquipmentSlot.SLOT) -> void:
    var equipment_slot := get_equipment_slot(slot)
    if equipment_slot:
        await equipment_slot.unequip()


## Retrieve a stat from the stat dictionary.
func get_stat(type: CombatStats.STATS) -> UnitGenericStat:
    var stat = (
        stat_dictionary[CombatStats.get_stat_as_string(type)]
        if stat_dictionary.has(CombatStats.get_stat_as_string(type))
        else null
    )
    return stat


##
## Checks if evaded for this unit.
func check_if_evaded() -> bool:
    var evaded: bool = false

    var evade_chance: int = int(snappedf(get_stat(CombatStats.STATS.Evasion).Current, 1.0))
    evaded = randomizer.roll(evade_chance)

    if not evaded:
        var lucky_evasion_chance: int = int(snappedf(get_stat(CombatStats.STATS.LuckyEvasion).Current, 1.0))
        evaded = randomizer.roll(lucky_evasion_chance)

    return evaded


##
## Checks if hit for this unit.
func check_if_hit(target: BattleUnit) -> bool:
    var hit: bool = false
    if next_attack_hits:
        next_attack_hits = false
        hit = true
        return hit

    var chance_to_hit: int = get_chance_to_hit()
    if chance_to_hit < 1:
        return hit

    var can_hit: bool = randomizer.roll(chance_to_hit)
    var target_evaded: bool = target.check_if_evaded()
    if can_hit and not target_evaded:
        hit = true

    return hit


##
## Checks if crit for this unit.
func check_if_crit() -> bool:
    return randomizer.roll(int(get_stat(CombatStats.STATS.CriticalStrike).Current))


## Returns chance to hit for this unit.
func get_chance_to_hit() -> int:
    var chance_to_hit: float = get_stat(CombatStats.STATS.Accuracy).Current
    return clampi(roundi(chance_to_hit), 0, 100)


## Returns targets from ai for this unit.
func get_targets_from_ai(selected_action: ActionTemplate) -> Dictionary:
    if has_madness():
        return {"targets": CombatActions.madness_targets(selected_action, self)}
    #TODO: MAKE AN ACTUAL AI.
    var selected: Dictionary
    var cloned_action: ActionTemplate = selected_action.duplicate()
    if selected_action.target == CombatActions.TARGET.FOE:
        cloned_action.target = CombatActions.TARGET.RANDOM_FOE
    elif selected_action.target == CombatActions.TARGET.ALLY:
        cloned_action.target = CombatActions.TARGET.RANDOM_ALLY

    # Invoke through a Callable to avoid a circular static type dependency while
    # BattleUnit itself is being compiled.
    var set_targets: Callable = CombatActions.set_targets
    selected = set_targets.call(cloned_action, self)

    return selected


##
## Triggers effects for this unit.
func trigger_effects(
    trigger: CombatEffects.TRIGGER,
    correlation_id: StringName = &"",
) -> StringName:
    var request_id := create_effect_request_id(trigger, correlation_id)
    effect_manager.trigger_effects(trigger, request_id)
    return request_id


## Resolves one exact request. Callers that own battle progression should await
## this method rather than waiting for the next observer signal.
func resolve_effects(
    trigger: CombatEffects.TRIGGER,
    correlation_id: StringName = &"",
    continuation: Callable = Callable(),
    context: Dictionary = {},
) -> StringName:
    var request_id := create_effect_request_id(trigger, correlation_id)
    await effect_manager.trigger_effects(trigger, request_id, continuation, context)
    return request_id


## Builds a unique effect request ID. [param correlation_id] should identify the
## owning action or round so presentation and resolution reports can be traced.
func create_effect_request_id(
    trigger: CombatEffects.TRIGGER,
    correlation_id: StringName = &"",
) -> StringName:
    _effect_request_serial += 1
    var prefix := String(correlation_id) if not correlation_id.is_empty() else "unit:%s" % get_instance_id()
    return StringName("%s:effects:%s:%s" % [prefix, trigger, _effect_request_serial])


##
## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    SignalBus.add_effect.connect(add_effect)
    if not effect_manager:
        effect_manager = get_meta(EFFECTS_MANAGER_NAME)
    if not effect_manager.effects_triggered.is_connected(after_effects_triggered):
        effect_manager.effects_triggered.connect(after_effects_triggered)
    randomizer = get_meta(RANDOMIZER_NAME)
    _synchronize_intrinsic_effects()
    if template_resource and template_resource.skill_collection:
        skills = BattleUnitSkills.new()
        skills.name = &"Skills"
        add_child(skills)
        for error in skills.initialize(self, template_resource.skill_collection):
            CustomLogger.error(self, _ready, error, CustomLogger.LEVEL.IMPORTANT)


## Rebuilds the effects that are an inherent part of the assigned character
## template. A stable source lets template replacement and explicit resyncs
## remove only the grants owned by this feature.
func _synchronize_intrinsic_effects() -> void:
    if not effect_manager:
        effect_manager = get_meta(EFFECTS_MANAGER_NAME)
    if not effect_manager:
        return
    if not _intrinsic_effect_source_id.is_empty():
        effect_manager.remove_effects_from_source(_intrinsic_effect_source_id)
        _intrinsic_effect_source_id = &""
    if not template_resource or template_resource.intrinsic_effects.is_empty():
        return
    _intrinsic_effect_source_id = StringName("intrinsic:%s" % template_resource.id)
    for effect_template: EffectTemplate in template_resource.intrinsic_effects:
        if effect_template:
            add_effect(
                self,
                self,
                effect_template,
                {"source_id": _intrinsic_effect_source_id},
            )


#region SAVE / LOAD
## Gets the state of the components of a unit, when the game is saved.
func _get_state() -> Dictionary:
    var state: Dictionary = stat_dictionary

    return state


## Restores the state of the components of a unit when, the game is loaded.
func on_load(passed_data: Dictionary) -> void:
    if not passed_data.has(save_name):
        return
    var data = passed_data[save_name]
    stat_dictionary = data


#endregion

## Fixed effects manager name value shared by all unit instances.
const EFFECTS_MANAGER_NAME: StringName = &"Effects"
## Fixed randomizer name value shared by all unit instances.
const RANDOMIZER_NAME: StringName = &"Randomizer"


## Constructs a new unit node from the supplied template.
static func create(template: BattleUnitTemplate, starting_equipment: bool = true) -> BattleUnit:
    var unit: BattleUnit = BattleUnitCreation.create(template, starting_equipment)
    return unit


## Madness owns AI even if a later generic control override requests player input.
func has_madness() -> bool:
    for source_id in _control_override_order:
        var source := instance_from_id(source_id)
        if source is EffectMadness and not source.removed and not source.is_queued_for_deletion():
            return true
    return false


## All eligible owned actions plus exclusive madness choices; ordinary AI keeps its order.
func get_ai_actions() -> Array[ActionTemplate]:
    var forced := get_forced_action_effect()
    if forced:
        return [forced.definition.action] if can_use_action(forced.definition.action, true) else []
    var result: Array[ActionTemplate] = []
    for action in get_owned_actions():
        if can_use_action(action, true):
            result.append(action)
    result.append_array(BattleMadnessAction.available(self))
    return result


const COWERING_SOURCE := &"madness_cowering_stance"
const COWERING_STATS := [
    CombatStats.STATS.Evasion, CombatStats.STATS.MagicResistance, CombatStats.STATS.PhysicalResistance
]


## Source-owned overrides preserve underlying defenses and leave Lucky Evasion alone.
func apply_cowering() -> void:
    clear_cowering()
    for stat_id in COWERING_STATS:
        var stat := get_stat(stat_id)
        if stat:
            stat.add_modifier(
                UnitStatModifier.create(
                    COWERING_SOURCE,
                    COWERING_SOURCE,
                    stat_id,
                    UnitStatModifier.OPERATION.OVERRIDE,
                    0.0,
                    UnitStatModifier.LIFETIME.WHILE_SOURCE_ACTIVE,
                    2147483647
                )
            )


## Called at the next turn and encounter cleanup, including defeat/retry paths.
func clear_cowering() -> void:
    for stat_id in COWERING_STATS:
        var stat := get_stat(stat_id)
        if stat:
            stat.remove_modifiers_from_source(COWERING_SOURCE)


## Shared dynamic check for menus, AI and automatic/normal execution validation.
func is_action_disabled_by_effects(action: ActionTemplate) -> bool:
    return (
        action != null
        and is_instance_valid(effect_manager)
        and effect_manager.has_any_effect_id(action.disabled_by_effects)
    )


## An applied mandate changes pending selection without restarting the turn.
signal forced_action_changed


## Highest priority wins, then latest application. Removed/unapplied effects never participate.
func get_forced_action_effect() -> EffectForceAction:
    var chosen: EffectForceAction
    if not is_instance_valid(effect_manager):
        return null
    for holder: EffectDirectors in effect_manager.triggers_to_holders.values():
        for effect in holder.get_children():
            if (
                effect is not EffectForceAction
                or not effect.active
                or effect.removed
                or effect.is_queued_for_deletion()
            ):
                continue
            if (
                not chosen
                or effect.definition.priority > chosen.definition.priority
                or (
                    effect.definition.priority == chosen.definition.priority
                    and effect.activation_order > chosen.activation_order
                )
            ):
                chosen = effect
    return chosen


## Stacked stuns remain effective until every applied source is removed or expires.
func is_stunned() -> bool:
    if not is_instance_valid(effect_manager):
        return false
    for holder: EffectDirectors in effect_manager.triggers_to_holders.values():
        for effect in holder.get_children():
            if effect is EffectStun and effect.active and not effect.removed and not effect.is_queued_for_deletion():
                return true
    return false
