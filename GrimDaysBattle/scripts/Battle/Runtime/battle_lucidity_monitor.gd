extends RefCounted
## Encounter-scoped turn-start Lucidity processing. Permanent units have no automatic breaks
## outside battle, and cleanup disconnects before retry or reward recovery.
class_name BattleLucidityMonitor

## Tracked unit/stat subscriptions removed when the encounter monitor stops.
var _connections: Array[Dictionary] = []
## Encounter-liveness callback guarding automatic effect activation.
var _continuation: Callable
## Units already handled at zero, including outcomes that finish immediately.
var _empty_units: Dictionary = {}
## Resolved immediate actions, recorded by the coordinator without spending a normal turn.
signal action_completed(resolution: BattleActionResolution)
## Temporary action grants revoked on completion or encounter cleanup.
var _action_grants: Dictionary = {}
## Serial makes each automatic action request distinct within the encounter.
var _action_serial: int = 0


## Track recovery only; encounter entry and stat changes never select an outcome.
## Eligibility and activation are evaluated by process_turn at the unit's turn start.
func start(roster: BattleEncounterRoster, continuation: Callable) -> void:
    stop()
    _continuation = continuation
    for unit in roster.get_participants():
        var template := unit.template_resource as MainCharacterTemplate
        if not template or template.lucidity_break_options.is_empty():
            continue
        var lucidity := unit.get_stat(CombatStats.STATS.Lucidity)
        if not lucidity:
            continue
        var callback := _on_lucidity_changed.bind(unit)
        lucidity.value_changed.connect(callback)
        _connections.append({"stat": lucidity, "callback": callback})


## Safe before repeated finish/cleanup calls. Does not refill pools or revoke
## unrelated control effects; the roster owns battle-effect removal.
func stop() -> void:
    _continuation = Callable()
    for connection in _connections:
        if connection.stat.value_changed.is_connected(connection.callback):
            connection.stat.value_changed.disconnect(connection.callback)
    _connections.clear()
    _empty_units.clear()
    for unit in _action_grants:
        if is_instance_valid(unit):
            unit.revoke_action_source(_action_grants[unit])
    _action_grants.clear()


## Recovery rearms the next turn's check, even while defeated. Never applies outcomes.
func _on_lucidity_changed(_stat: UnitGenericStat, _old: float, current: float, unit: BattleUnit) -> void:
    if current > 0:
        _empty_units.erase(unit)


## Called and awaited only for the unit starting its turn, before action selection.
## Repeated empty turns neither stack nor refresh an existing break.
func process_turn(unit: BattleUnit) -> void:
    if not _continuation.is_valid() or not _continuation.call() or not is_instance_valid(unit) or not unit.is_active:
        return
    var lucidity := unit.get_stat(CombatStats.STATS.Lucidity)
    if not lucidity or lucidity.Max <= 0:
        return
    if lucidity.Current > 0:
        _empty_units.erase(unit)
        return
    if _empty_units.has(unit):
        return
    var source := StringName("lucidity_break:%s" % unit.get_instance_id())
    if not unit.effect_manager.get_effects_from_source(source).is_empty():
        return
    var template := unit.template_resource as MainCharacterTemplate
    if not template or template.lucidity_break_options.is_empty():
        return
    var selected := _pick_option(template, unit)
    if not selected:
        return
    # Latch before application because an outcome can synchronously change watched stats.
    _empty_units[unit] = true
    if selected.action:
        await _execute_action(unit, selected, source, _continuation)
        return
    var definition := selected.effect.duplicate() as EffectTemplate
    var effect := unit.add_effect(unit, unit, definition, {"source_id": source})
    if effect:
        var holder := effect.get_parent() as EffectDirectors
        await holder.trigger_selected_effects(source, [effect], _continuation)


## Roll valid positive-weight entries using the combatant's seeded stream.
func _pick_option(template: MainCharacterTemplate, unit: BattleUnit) -> LucidityBreakOption:
    var candidates: Array[LucidityBreakOption] = []
    var total: float = 0.0
    for option in template.lucidity_break_options:
        if option and option.weight > 0.0 and option.validate().is_empty():
            if option.action and unit.is_action_disabled_by_effects(option.action):
                continue
            candidates.append(option)
            total += option.weight
    if candidates.is_empty():
        return null
    var roll := unit.randomizer.random_number_generator.randf_range(0.0, total)
    for option in candidates:
        roll -= option.weight
        if roll < 0.0:
            return option
    return candidates.back()


## Use a temporary source grant so automatic actions do not become learned skills.
## Automatic outcomes bypass costs and cooldowns; targeting and cancellation still apply.
func _execute_action(unit: BattleUnit, option: LucidityBreakOption, source: StringName, continuation: Callable) -> void:
    if _action_grants.has(unit):
        return
    _action_serial += 1
    var action_source := StringName("%s:action:%s" % [source, _action_serial])
    if not unit.grant_action_from_source(action_source, option.action, option.action_rank):
        return
    _action_grants[unit] = action_source
    var targets: Array[BattleUnit] = []
    targets.assign(unit.get_targets_from_ai(option.action).get("targets", []))
    var resolver := BattleActionResolver.new()
    unit.add_child(resolver)
    var request := BattleActionRequest.new(action_source, unit, option.action, targets, true)
    var resolution: BattleActionResolution = await resolver.resolve(request, continuation)
    if is_instance_valid(unit) and _action_grants.get(unit) == action_source:
        unit.revoke_action_source(action_source)
        _action_grants.erase(unit)
    if is_instance_valid(resolver):
        resolver.queue_free()
    if continuation.is_valid() and continuation.call():
        action_completed.emit(resolution)
