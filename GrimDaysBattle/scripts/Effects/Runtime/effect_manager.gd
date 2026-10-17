extends Node
#region EFFECTS MANAGER
## Responsible for passing effects to directors that target the owner of this node.
class_name EffectsManager
#endregion

## Maximum completed report batches retained for consumers that resolve later.
const MAX_CACHED_RESOLUTION_REPORTS: int = 32

#region ON READY
## Effects that trigger when an item is equipped.
@onready var on_equip_holder: EffectDirectors = %"On Equip"
## Effects that trigger before the owner is hit in combat.
@onready var before_hit_holder: EffectDirectors = %"Before Hit"
## Effects that trigger after the owner is hit in combat.
@onready var after_hit_holder: EffectDirectors = %"After Hit"
## Effects that trigger before the owner hit's a target in combat.
@onready var before_hitting_holder: EffectDirectors = %"Before Hitting"
## Effects that trigger after the owner hit's a target in combat.
@onready var after_hitting_holder: EffectDirectors = %"After Hitting"
## Effects that trigger after the owner is defeated.
@onready var on_defeat_holder: EffectDirectors = %"On Defeat"
## Effects that trigger after the owner defeats a target in combat.
@onready var on_kill_holder: EffectDirectors = %"On Kill"
## Effects that trigger after the owner uses a skill in combat.
@onready var on_processing_finished_holder: EffectDirectors = %"On Processing Finished"
## Effects that trigger when a combat round ends.
@onready var on_round_over_holder: EffectDirectors = %"On Round Over"

## Cached reference to the parent node, resolved when this node becomes ready.
@onready var parent: BattleUnit = get_parent()

#endregion
## Emitted when effects triggered.
signal effects_triggered(request_id: StringName)
#region VARIABLES
## A dictionary of the holder nodes, used to pass control of adding an effect to the appropriate node.
var triggers_to_holders: Dictionary
## Monotonic fallback serial used when a caller does not supply a request ID.
var request_serial: int
## Effect outcome reports awaiting consumption by their correlated resolver call.
var resolution_reports: Dictionary[StringName, Array]
## Oldest-to-newest request IDs used to bound [member resolution_reports].
var resolution_report_order: Array[StringName]

#endregion


#region INIT
## Run after entering the tree.
func _ready() -> void:
    parent.set_meta(name, self)
    var before_damage := EffectDirectors.new()
    before_damage.name = &"Before Damage"
    add_child(before_damage)
    triggers_to_holders.set(CombatEffects.TRIGGER.BEFORE_DAMAGE, before_damage)
    triggers_to_holders.set(CombatEffects.TRIGGER.DAMAGED, after_hit_holder)
    triggers_to_holders.set(CombatEffects.TRIGGER.AFTER_HITTING, after_hitting_holder)
    triggers_to_holders.set(CombatEffects.TRIGGER.TARGETED, before_hit_holder)
    triggers_to_holders.set(CombatEffects.TRIGGER.ATTACKING, before_hitting_holder)
    triggers_to_holders.set(CombatEffects.TRIGGER.DEFEAT, on_defeat_holder)
    triggers_to_holders.set(CombatEffects.TRIGGER.KILL, on_kill_holder)
    triggers_to_holders.set(CombatEffects.TRIGGER.EQUIP, on_equip_holder)
    triggers_to_holders.set(CombatEffects.TRIGGER.PROCESS_OVER, on_processing_finished_holder)
    triggers_to_holders.set(CombatEffects.TRIGGER.ROUND_OVER, on_round_over_holder)


#region MAIN
## Returns attached for this effects manager.
func get_attached() -> Node:
    return get_parent()


## Adds the supplied effect to the unit under the triggering category.
func add_effect(sender: Node, target: Node, effect: EffectTemplate, context: Dictionary = {}) -> EffectBase:
    if effect.lifetime == EffectTemplate.LIFETIME.ROUNDS and effect.duration < 1:
        (
            CustomLogger
            . error(
                self,
                add_effect,
                "Round-based effect %s requires a positive duration." % effect.id,
                CustomLogger.LEVEL.IMPORTANT,
            )
        )
        return null
    var holder: EffectDirectors = triggers_to_holders.get(effect.trigger)
    if not holder:
        (
            CustomLogger
            . error(
                self,
                add_effect,
                "No effect director registered for trigger %s." % effect.trigger,
                CustomLogger.LEVEL.IMPORTANT,
            )
        )
        return null
    return holder.add_effect(sender, target, effect, context)


## Triggers effects for this effects manager.
func trigger_effects(
    trigger: CombatEffects.TRIGGER,
    request_id: StringName = &"",
    continuation: Callable = Callable(),
    context: Dictionary = {},
) -> StringName:
    if request_id.is_empty():
        request_serial += 1
        request_id = StringName("effects:%s:%s:%s" % [get_instance_id(), trigger, request_serial])
    CustomLogger.confirm(
        self, trigger_effects, "Triggering effects for trigger: " + str(trigger), CustomLogger.LEVEL.VERBOSE
    )
    var holder: EffectDirectors = triggers_to_holders.get(trigger)
    if not holder:
        (
            CustomLogger
            . warn(
                self,
                trigger_effects,
                "No effect director registered for trigger %s." % trigger,
                CustomLogger.LEVEL.IMPORTANT,
            )
        )
        _store_resolution_reports(request_id, [])
        after_effects_trigger(request_id)
        return request_id
    await holder.trigger_effects(request_id, continuation, context)
    _store_resolution_reports(request_id, holder.last_resolution_reports)
    after_effects_trigger(request_id)
    return request_id


## Handles effects trigger for this effects manager.
func after_effects_trigger(request_id: StringName) -> void:
    CustomLogger.confirm(self, after_effects_trigger, "Effects triggered.", CustomLogger.LEVEL.VERBOSE)
    effects_triggered.emit(request_id)


## Returns whether effects to trigger.
func has_effects_to_trigger(trigger: CombatEffects.TRIGGER) -> bool:
    var holder: EffectDirectors = triggers_to_holders.get(trigger)
    return holder.has_effects_to_trigger() if holder else false


## Returns and removes reports belonging to one completed trigger request.
func take_resolution_reports(request_id: StringName) -> Array[Dictionary]:
    var reports: Array[Dictionary] = []
    if resolution_reports.has(request_id):
        reports.assign(resolution_reports[request_id])
        resolution_reports.erase(request_id)
        resolution_report_order.erase(request_id)
    return reports


## Stores one correlated report batch while bounding legacy/unconsumed entries.
func _store_resolution_reports(request_id: StringName, reports: Array) -> void:
    resolution_report_order.erase(request_id)
    resolution_reports[request_id] = reports.duplicate(true)
    resolution_report_order.append(request_id)
    while resolution_report_order.size() > MAX_CACHED_RESOLUTION_REPORTS:
        resolution_reports.erase(resolution_report_order.pop_front())


## Removes every active effect granted by one runtime source, such as an
## equipment node. Effect cleanup reverses the source's stat modifiers.
func remove_effects_from_sender(sender: Node) -> void:
    for holder: EffectDirectors in triggers_to_holders.values():
        for effect in holder.get_children():
            if effect is EffectBase and effect.sender == sender:
                effect.remove()


## Removes effects from source for this effects manager.
func remove_effects_from_source(source_id: StringName) -> void:
    for effect in get_effects_from_source(source_id):
        effect.remove()


## Returns effects from source for this effects manager.
func get_effects_from_source(source_id: StringName) -> Array[EffectBase]:
    var matching: Array[EffectBase] = []
    for holder: EffectDirectors in triggers_to_holders.values():
        for effect in holder.get_children():
            if effect is EffectBase and not effect.is_queued_for_deletion() and effect.source_id == source_id:
                matching.append(effect)
    return matching


## Removes effects with source prefix for this effects manager.
func remove_effects_with_source_prefix(prefix: String) -> void:
    for holder: EffectDirectors in triggers_to_holders.values():
        for effect in holder.get_children():
            if effect is EffectBase and String(effect.source_id).begins_with(prefix):
                effect.remove()


## Removes battle-scoped effects while retaining equipment/passive grants and
## progression effects that belong to the runtime unit outside this encounter.
func remove_battle_scoped_effects() -> void:
    for holder: EffectDirectors in triggers_to_holders.values():
        for effect in holder.get_children():
            if effect is not EffectBase:
                continue
            if (
                effect is EffectTargetSubstitution
                or (
                    effect.lifetime
                    in [
                        EffectTemplate.LIFETIME.INSTANT,
                        EffectTemplate.LIFETIME.ROUNDS,
                        EffectTemplate.LIFETIME.UNTIL_BATTLE_END,
                    ]
                )
            ):
                effect.remove()


## Production round boundaries affect this unit only, never unrelated parties.
func advance_round() -> void:
    # Snapshot all holders before expiry can add children to a later trigger bucket.
    var round_effects: Array[Node] = []
    for holder: EffectDirectors in triggers_to_holders.values():
        round_effects.append_array(holder.get_children())
    for effect in round_effects:
        if is_instance_valid(effect) and effect is EffectBase and not effect.is_queued_for_deletion():
            effect.on_round_end()


#endregion


## Selection-time presence query: attached defensive effects count before their first
## trigger. Removed and queued effects stop blocking immediately, across all holders.
func has_any_effect_id(effect_ids: Array[StringName]) -> bool:
    if effect_ids.is_empty():
        return false
    for holder: EffectDirectors in triggers_to_holders.values():
        for effect in holder.get_children():
            if (
                effect is EffectBase
                and not effect.removed
                and not effect.is_queued_for_deletion()
                and StringName(effect.id) in effect_ids
            ):
                return true
    return false


## Own immediate follow-up completion here: the expired parent is already queued for deletion.
## Retained children keep their authored trigger; EQUIP directors apply them on attachment.
func grant_expiry_effect(origin: Node, definition: EffectTemplate, context: Dictionary) -> void:
    var effect := add_effect(origin, parent, definition, context)
    if not effect or definition.lifetime != EffectTemplate.LIFETIME.INSTANT:
        return
    effect.apply()
    while is_instance_valid(effect) and not effect.is_queued_for_deletion() and not effect.finished:
        await get_tree().process_frame
    if is_instance_valid(effect) and not effect.is_queued_for_deletion():
        effect.complete_trigger_cycle()
