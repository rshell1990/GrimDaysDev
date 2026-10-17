extends RefCounted
## Short-lived, encounter-local observer of primitive resource effects. Captures
## ordered outcomes without polling net Health or relying on global UI signals.
## Always close after awaited work, including cancellation, to release units.
class_name BattleResourceEventCapture

## Events in operation order; returned events contain copied operation metadata.
var events: Array[BattleCombatEvent] = []

## Immediate notification for feedback before a carried animation delay.
signal operation_resolved(event: BattleCombatEvent)
## Units whose resource, hit, targeting and turn-order signals are being captured.
var _units: Array[BattleUnit] = []
## Optional originating action request used for actor attribution.
var _request: BattleActionRequest
## Stable identifier attached to captured combat events.
var _request_id: StringName
## Additional lifecycle/action metadata merged into operation reports.
var _context: Dictionary


## Observes each unit once, including defeated units that lifecycle hooks may revive.
func _init(
    units: Array[BattleUnit],
    request: BattleActionRequest = null,
    request_id: StringName = &"",
    context: Dictionary = {}
) -> void:
    _request = request
    _request_id = request.request_id if request else request_id
    _context = context.duplicate(true)
    for unit in units:
        if is_instance_valid(unit) and unit not in _units:
            _units.append(unit)
            unit.resource_operation_resolved.connect(_on_operation)
            unit.turn_order_operation_resolved.connect(_on_turn_delay)
            unit.damage_hit_resolved.connect(_on_damage_hit)
            unit.action_targeted.connect(_on_targeted)
            unit.action_substituted.connect(_on_substituted)


## Disconnects only this observer. Safe after cancellation, unit deletion or repeated close.
func close() -> void:
    for unit in _units:
        if is_instance_valid(unit) and unit.resource_operation_resolved.is_connected(_on_operation):
            unit.resource_operation_resolved.disconnect(_on_operation)
        if is_instance_valid(unit) and unit.turn_order_operation_resolved.is_connected(_on_turn_delay):
            unit.turn_order_operation_resolved.disconnect(_on_turn_delay)
        if is_instance_valid(unit) and unit.damage_hit_resolved.is_connected(_on_damage_hit):
            unit.damage_hit_resolved.disconnect(_on_damage_hit)
        if is_instance_valid(unit) and unit.action_targeted.is_connected(_on_targeted):
            unit.action_targeted.disconnect(_on_targeted)
        if is_instance_valid(unit) and unit.action_substituted.is_connected(_on_substituted):
            unit.action_substituted.disconnect(_on_substituted)
    _units.clear()


## Turn-order events share the action/lifecycle capture scope and ordering but
## are never mislabeled as damage, resource loss or an additional turn.
func _on_turn_delay(report: Dictionary) -> void:
    var data := report.duplicate(true)
    data.merge(_context, false)
    _append(BattleCombatEvent.TYPE.TURN_DELAY, data)


## Copies the hit report, merges capture context and records HIT or MISS with the original action
## actor when available.
func _on_damage_hit(report: Dictionary) -> void:
    var data := report.duplicate(true)
    data.merge(_context, false)
    if _request:
        data["action_actor"] = _request.actor
    _append(BattleCombatEvent.TYPE.HIT if data.hit else BattleCombatEvent.TYPE.MISS, data)


## Copies the selection report into a BEFORE_TARGETED event while preserving reaction source and
## original action attribution.
func _on_targeted(report: Dictionary) -> void:
    var data := report.duplicate(true)
    data.merge(_context, false)
    if _request:
        data["action_actor"] = _request.actor
    _append(BattleCombatEvent.TYPE.BEFORE_TARGETED, data)


## The historical target is metadata only; the event's target is the actual replacement.
func _on_substituted(report: Dictionary) -> void:
    var data := report.duplicate(true)
    data.merge(_context, false)
    _append(BattleCombatEvent.TYPE.TARGET_SUBSTITUTED, data)


## Copies each primitive result before later operations can overwrite effect state.
## Critical precedes its resource event; defeat/revival follows the Health transition.
func _on_operation(report: Dictionary) -> void:
    var data := report.duplicate(true)
    data.merge(_context, false)
    if _request:
        data["action_actor"] = _request.actor
    if data.get("critical", false):
        _append(BattleCombatEvent.TYPE.CRITICAL, data)
    if data.stat != CombatStats.STATS.Health:
        _append(BattleCombatEvent.TYPE.RESOURCE_CHANGED, data)
    else:
        # A zero-valued attack is still damage, not healing. Restoration reports
        # have no damage type even when a template also configures one.
        var is_damage: bool = data.damage_type != CombatDamage.TYPE.None or data.raw_change < 0
        _append(BattleCombatEvent.TYPE.DAMAGE if is_damage else BattleCombatEvent.TYPE.HEALING, data)
        if data.before > 0 and data.after <= 0:
            _append(BattleCombatEvent.TYPE.DEFEAT, data)
        elif data.before <= 0 and data.after > 0:
            _append(BattleCombatEvent.TYPE.REVIVED, data)


## Lifecycle scopes have no action, but still carry an attempt-correlated request ID.
func _append(type: BattleCombatEvent.TYPE, data: Dictionary) -> void:
    var event := BattleCombatEvent.new(type, _request, data.recipient, data.resolved_change, data)
    event.request_id = _request_id
    event.actor = data.source
    if type in [BattleCombatEvent.TYPE.DEFEAT, BattleCombatEvent.TYPE.REVIVED]:
        event.amount = 0
    events.append(event)
    operation_resolved.emit(event)
