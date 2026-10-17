extends RefCounted
## Coordinates unit generic stat behavior for the battle system.
class_name UnitGenericStat

## Emitted when changed.
signal changed(this, amount)
## Emitted when value changed.
signal value_changed(stat, old_value, new_value)

## Runtime original template state used by this unit generic stat.
var original_template: UnitStatTemplate
## Stable id used to correlate or persist this unit generic stat.
var id: CombatStats.STATS
## Runtime name state used by this unit generic stat.
var name: StringName
## Runtime owner of this unit generic stat.
var owner: BattleUnit

## Runtime base state used by this unit generic stat.
var _base: float
## Runtime base state used by this unit generic stat.
var Base: float:
    get:
        return _base

## Runtime min state used by this unit generic stat.
var _min: float
## Runtime min state used by this unit generic stat.
var Min: float:
    get:
        return _min

## Runtime max state used by this unit generic stat.
var _max: float
## Runtime max state used by this unit generic stat.
var Max: float:
    get:
        return _max

## Runtime current state used by this unit generic stat.
var _current: float
## Runtime current state used by this unit generic stat.
var Current: float:
    get:
        return _current

## Current value normalized to the inclusive 0.0-1.0 range. Empty pools
## deliberately report 0.0 instead of dividing by zero.
var ratio: float:
    get:
        if _max <= 0.0:
            return 0.0
        return clampf(_current / _max, 0.0, 1.0)

## Current value expressed as a percentage of Max.
var percentage: float:
    get:
        return ratio * 100.0

## Runtime scales from attribute state used by this unit generic stat.
var scales_from_attribute: CombatStats.STATS = CombatStats.STATS.Empty

## Active modifiers keyed by a unique modifier id. Multiple modifiers may share
## a source id and can be removed together with [method remove_modifiers_from_source].
var mods: Dictionary[StringName,UnitStatModifier]

## Runtime-only source locks; insertion order breaks equal-priority ties.
var current_locks: Dictionary = {}
var unlocked_current: float


## Exact finite values may exceed normal bounds while locked. Base/Max remain independent.
func add_current_lock(lock_id: StringName, value: float, priority: int = 0) -> void:
    if lock_id.is_empty() or not is_finite(value):
        return
    var old_current := _current
    if current_locks.is_empty():
        unlocked_current = _current
    current_locks[lock_id] = {"value": value, "priority": priority}
    _current = _locked_value()
    _emit_change(old_current, _max)


## Restores the underlying value when the last lock disappears; blocked mutations are discarded.
func remove_current_lock(lock_id: StringName) -> void:
    if not current_locks.erase(lock_id):
        return
    var old_current := _current
    _current = clampf(unlocked_current, _min, _max) if current_locks.is_empty() else _locked_value()
    _emit_change(old_current, _max)


func _locked_value() -> float:
    var chosen: Dictionary = {}
    for entry: Dictionary in current_locks.values():
        if chosen.is_empty() or entry.priority >= chosen.priority:
            chosen = entry
    return chosen.value


## Recalculation still updates the value underneath a lock before publishing the fixed Current.
func _apply_current_lock() -> void:
    if not current_locks.is_empty():
        unlocked_current = _current
        _current = _locked_value()


## Initializes this unit generic stat from the supplied runtime dependencies.
func setup(template: UnitStatTemplate, sender: BattleUnit) -> void:
    original_template = template
    _base = template.starting_amount
    _min = 0
    id = template.type
    name = template.id
    owner = sender
    _refresh_from_base(false)


## Sets base for this unit generic stat.
func set_base(new_base: float) -> void:
    _base = new_base
    _refresh_from_base()


## Changes min for this unit generic stat.
func change_min(new_min: float) -> void:
    _min = new_min
    _refresh_from_base()


## Handles max flat for this unit generic stat.
func increase_max_flat(amount: float) -> void:
    set_base(_base + amount)


## Handles current flat for this unit generic stat.
func increase_current_flat(amount: float) -> void:
    if not current_locks.is_empty():
        return
    var old_current := _current
    _current += amount
    _current = clampf(snappedf(_current, 1.0), _min, _max)
    _emit_change(old_current, _max)


## Handles max flat for this unit generic stat.
func decrease_max_flat(amount: float) -> void:
    set_base(_base - amount)


## Handles current flat for this unit generic stat.
func decrease_current_flat(amount: float) -> void:
    if not current_locks.is_empty():
        return
    var old_current := _current
    _current -= amount
    _current = clampf(snappedf(_current, 1.0), _min, _max)
    _emit_change(old_current, _max)


## Save reconstruction restores the exact pool value after all maximum grants.
## Unlike combat mutations, restoration must not round fractional saved values.
func restore_current(value: float) -> void:
    if not current_locks.is_empty():
        return
    var old_current := _current
    _current = clampf(value, _min, _max)
    _emit_change(old_current, _max)


## Adds or replaces one modifier, then recalculates the effective stat value.
func add_modifier(modifier: UnitStatModifier) -> void:
    if not modifier:
        push_error("Cannot add a null modifier to %s." % name)
        return
    if modifier.modifier_id.is_empty():
        push_error("A modifier for %s must have a modifier_id." % name)
        return
    if modifier.stat != id:
        push_error(
            (
                "Modifier %s targets %s, not %s."
                % [modifier.modifier_id, CombatStats.get_stat_as_string(modifier.stat), name]
            )
        )
        return
    mods[modifier.modifier_id] = modifier
    _refresh_from_base()


## Removes modifier for this unit generic stat.
func remove_modifier(modifier_id: StringName) -> void:
    if not mods.erase(modifier_id):
        return
    _refresh_from_base()


## Removes modifiers from source for this unit generic stat.
func remove_modifiers_from_source(source_id: StringName) -> void:
    var removed := false
    for modifier_id in mods.keys():
        if mods[modifier_id].source_id == source_id:
            mods.erase(modifier_id)
            removed = true
    if removed:
        _refresh_from_base()


## Returns modifiers from source for this unit generic stat.
func get_modifiers_from_source(source_id: StringName) -> Array[UnitStatModifier]:
    var matching: Array[UnitStatModifier]
    for modifier in mods.values():
        if modifier.source_id == source_id:
            matching.append(modifier)
    return matching


## Replaces the unmodified value used by calculated and scaled stats.
func set_calculated_base(new_base: float, preserve_ratio: bool = true) -> void:
    _base = new_base
    _refresh_from_base(preserve_ratio)


## Restore as part of a whole-block retry transaction, with visuals unbound.
## The checkpoint contains already-evaluated dependencies: replaying `changed`
## would recompute a partially restored graph and round fractional pool values.
func restore_retry_values(base: float, minimum: float, maximum: float, current: float) -> void:
    _base = base
    _min = minimum
    _max = maximum
    _current = current


## Applies modifiers in a stable operation order. Percent values are fractions:
## 0.15 means +15%, while MULTIPLY uses its amount directly (1.15 means x1.15).
func calculate_modified_value(base_value: float) -> float:
    var flat_add: float
    var percent_add: float
    var multiplier: float = 1.0
    var overrides: Array[UnitStatModifier]
    var capped_additions: Array[UnitStatModifier]

    for modifier in mods.values():
        match modifier.operation:
            UnitStatModifier.OPERATION.FLAT_ADD:
                flat_add += modifier.amount
            UnitStatModifier.OPERATION.PERCENT_ADD:
                percent_add += modifier.amount
            UnitStatModifier.OPERATION.MULTIPLY:
                multiplier *= modifier.amount
            UnitStatModifier.OPERATION.CAPPED_ADD:
                capped_additions.append(modifier)
            UnitStatModifier.OPERATION.OVERRIDE:
                overrides.append(modifier)

    var result := (base_value + flat_add) * (1.0 + percent_add) * multiplier
    if not overrides.is_empty():
        overrides.sort_custom(func(a: UnitStatModifier, b: UnitStatModifier): return a.priority < b.priority)
        result = overrides.back().amount
    # Final scaled contributions are source-owned, not a global defense cap.
    capped_additions.sort_custom(
        func(a: UnitStatModifier, b: UnitStatModifier):
            return a.priority < b.priority if a.priority != b.priority else a.modifier_id < b.modifier_id
    )
    for modifier in capped_additions:
        result += minf(maxf(modifier.amount, 0.0), maxf(modifier.contribution_cap - result, 0.0))
    return result


## Updates Max and Current without executing modifier-owned behavior. Resource
## pools retain their percentage filled when their effective maximum changes.
func _refresh_from_base(preserve_ratio: bool = true) -> void:
    var old_current := _current
    var old_max := _max
    var old_ratio := 1.0
    if preserve_ratio and old_max > 0.0:
        old_ratio = clampf((old_current if current_locks.is_empty() else unlocked_current) / old_max, 0.0, 1.0)

    _max = maxf(calculate_modified_value(_base), _min)
    _current = clampf(_max * old_ratio, _min, _max)
    _apply_current_lock()
    _emit_change(old_current, old_max)


## Emits change for this unit generic stat.
func _emit_change(old_current: float, old_max: float) -> void:
    if is_equal_approx(old_current, _current) and is_equal_approx(old_max, _max):
        return
    var amount := _current - old_current
    changed.emit(name, amount)
    value_changed.emit(self, old_current, _current)
