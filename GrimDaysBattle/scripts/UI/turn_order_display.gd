extends Node
## Keeps portrait identities and animates changes using the authored round slots.
class_name UnitTurnOrderDisplay

@export var turn_bar: Node
@export var portrait_template: PackedScene
@export var production_mode: bool = false
var _legacy_units: Array[BattleUnit] = []
var _legacy_round: int = 0


func _ready() -> void:
    for marker in turn_bar.get_children():
        marker.hide()
    if not production_mode:
        SignalBus.init_turn_order.connect(setup)
        SignalBus.set_next_unit.connect(try_to_shift_left)
        SignalBus.units_removed_from_turn.connect(on_unit_removed)


func setup(units: Array) -> void:
    _legacy_units.assign(units)
    _legacy_round += 1
    show_order(_legacy_units, _legacy_round)


func try_to_shift_left() -> void:
    if not _legacy_units.is_empty():
        _legacy_units.pop_front()
    show_order(_legacy_units, _legacy_round)


func on_unit_removed(indices: Array[int]) -> void:
    var remaining: Array[BattleUnit] = []
    for index in _legacy_units.size():
        if index not in indices:
            remaining.append(_legacy_units[index])
    _legacy_units = remaining
    show_order(_legacy_units, _legacy_round)


## Production portraits retain identity and move between the round's original slots.
var _portraits: Dictionary = {}
var _displayed_units: Array[BattleUnit] = []
var _snapshots: Array[Dictionary] = []
var _slot_positions: Array[Vector2] = []
var _slot_scales: Array[Vector2] = []
var _order_tween: Tween
var _round_revision: int = -1


func show_order(units: Array[BattleUnit], round_revision: int = 0) -> void:
    if units.is_empty():
        _clear_order()
        return
    _snapshots.append({"units": units.duplicate(), "round": round_revision})
    if not is_instance_valid(_order_tween) or not _order_tween.is_running():
        _present_next_order()


func _clear_order() -> void:
    if is_instance_valid(_order_tween):
        _order_tween.kill()
    _snapshots.clear()
    for portrait in _portraits.values():
        portrait.queue_free()
    _portraits.clear()
    _displayed_units.clear()
    _slot_positions.clear()
    _slot_scales.clear()
    _round_revision = -1


func _present_next_order() -> void:
    if _snapshots.is_empty():
        return
    var snapshot: Dictionary = _snapshots.pop_front()
    var units: Array[BattleUnit] = snapshot.units
    var new_round: bool = snapshot.round != _round_revision or _slot_positions.is_empty()
    if new_round:
        _round_revision = snapshot.round
        _build_slots(units.size())
    else:
        # Read occupied transforms before changing any portrait. Queuing updates means
        # a second delay reads the settled result of the first, never a half-tween.
        for index in _displayed_units.size():
            var previous: Control = _portraits[_displayed_units[index]]
            _slot_positions[index] = previous.position
            _slot_scales[index] = previous.scale
    if units.size() > _slot_positions.size():
        _build_slots(units.size())
    _order_tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
    for unit in _displayed_units:
        if unit not in units:
            var removed: Control = _portraits[unit]
            _portraits.erase(unit)
            removed.queue_free()
    for index in units.size():
        var unit: BattleUnit = units[index]
        var portrait: UnitTurnDisplayer = _portraits.get(unit)
        if not is_instance_valid(portrait):
            portrait = portrait_template.instantiate() as UnitTurnDisplayer
            portrait.set_anchors_preset(Control.PRESET_TOP_LEFT)
            portrait.setup(unit.template_resource)
            turn_bar.add_child(portrait)
            portrait.position = _slot_positions[index]
            portrait.scale = _slot_scales[index]
            portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
            _portraits[unit] = portrait
        portrait.tooltip_text = "%s. %s" % [index + 1, unit.template_resource.display_name]
        _order_tween.tween_property(portrait, "position", _slot_positions[index], AnimationTimes.STANDARD)
        _order_tween.tween_property(portrait, "scale", _slot_scales[index], AnimationTimes.STANDARD)
    _displayed_units.assign(units)
    _order_tween.finished.connect(_present_next_order, CONNECT_ONE_SHOT)


func _build_slots(count: int) -> void:
    var first: Control = %"Unit Template First"
    var last: Control = %"Unit Template Last"
    var center: Control = %"Unit Template"
    _slot_positions.clear()
    _slot_scales.clear()
    for index in count:
        var weight: float = float(index) / maxi(count - 1, 1)
        var slot: Vector2 = first.position.lerp(last.position, weight)
        slot.y = center.position.y
        _slot_positions.append(slot)
        _slot_scales.append(first.scale.lerp(last.scale, weight))
