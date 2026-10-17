extends RefCounted
## Keeps the turn list for one battle. It works without screen displays or game-wide notifications.
class_name BattleTurnOrder

## Units still waiting for a turn this round, ordered from fastest to slowest.
var _units: Array[BattleUnit] = []
## Once a unit starts acting, a counter cannot retroactively delay its turn.
var _acting_unit: BattleUnit
var round_revision: int = 0
signal changed
var waited: Dictionary = {}
var started: Dictionary = {}


## Builds this round's turn list from units that can fight, fastest first.
## Units with equal speed keep the order in which they were supplied.
func begin_round(participants: Array[BattleUnit]) -> void:
    round_revision += 1
    _units.clear()
    _acting_unit = null
    waited.clear()
    started.clear()
    for unit in participants:
        if not is_instance_valid(unit) or not unit.is_active or unit in _units:
            continue
        var index: int = 0
        while index < _units.size() and _speed(_units[index]) >= _speed(unit):
            index += 1
        _units.insert(index, unit)
    changed.emit()


## Returns a separate copy of the remaining turn list, containing the same unit objects.
func get_units() -> Array[BattleUnit]:
    return _units.duplicate()


## Skips units that no longer exist or cannot fight, then returns the next unit to act, or null if
## none remain.
func get_active_unit() -> BattleUnit:
    while not _units.is_empty():
        if is_instance_valid(_units[0]) and _units[0].is_active:
            return _units[0]
        _units.pop_front()
        _acting_unit = null
    return null


## Commits the next unit's turn once. Pending-order changes never tick cooldowns
## or increase turn counts; only the coordinator's actual turn start does so.
func mark_turn_started() -> bool:
    var unit := get_active_unit()
    if not unit or _acting_unit != null:
        return false
    _acting_unit = unit
    if started.has(unit):
        return false
    started[unit] = true
    return true


## Swap with the next still-active pending unit, if any. Already-acted, current,
## defeated and last-in-order units cannot be delayed. No turn is lost or added,
## and begin_round rebuilds the next round normally from effective speed.
func delay_pending(unit: BattleUnit) -> bool:
    if not is_instance_valid(unit) or not unit.is_active or unit == _acting_unit:
        return false
    var index := _units.find(unit)
    if index < 0:
        return false
    for next_index in range(index + 1, _units.size()):
        var next_unit := _units[next_index]
        if is_instance_valid(next_unit) and next_unit.is_active:
            _units[index] = next_unit
            _units[next_index] = unit
            changed.emit()
            return true
    return false


## Removes the first unit from the turn list if the list is not empty.
func advance() -> void:
    if not _units.is_empty():
        _units.pop_front()
    _acting_unit = null


## Removes the supplied defeated units and any deleted units from the turn list.
## Returns their list positions from last to first so displays can remove matching entries without
## shifting later positions.
func remove_defeated(defeated: Array[BattleUnit]) -> Array[int]:
    var removed: Array[int] = []
    for index in range(_units.size() - 1, -1, -1):
        if not is_instance_valid(_units[index]) or _units[index] in defeated:
            if _units[index] == _acting_unit:
                _acting_unit = null
            _units.remove_at(index)
            removed.append(index)
    if not removed.is_empty():
        changed.emit()
    return removed


## Discards all remaining turns.
func clear() -> void:
    _units.clear()
    _acting_unit = null
    waited.clear()
    started.clear()


func can_wait(unit: BattleUnit) -> bool:
    return (
        unit == _acting_unit
        and not waited.has(unit)
        and _units.any(func(other): return other != unit and is_instance_valid(other) and other.is_active)
    )


func wait_turn(unit: BattleUnit) -> bool:
    if not can_wait(unit):
        return false
    waited[unit] = true
    _units.erase(unit)
    _units.append(unit)
    _acting_unit = null
    changed.emit()
    return true


## Returns the unit's current speed for round ordering.
func _speed(unit: BattleUnit) -> float:
    return unit.speed
