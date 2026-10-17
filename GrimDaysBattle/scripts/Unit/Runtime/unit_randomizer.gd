extends Node
## Owns a combatant's random stream and fixed six-failure streak protection.
class_name UnitRandomizationControl

## Six completed failures make the next eligible protected roll succeed.
const FAILURE_PROTECTION: int = 6

## Minimum accepted authored percentage.
const MIN_CHANCE: float = 0.0
## Maximum accepted authored percentage.
const MAX_CHANCE: float = 100.0

## The amount of random events in a row for the unit that had negative results.
var fails: int

## RNG owned by this unit so combat can be reproduced from a seed.
var random_number_generator: RandomNumberGenerator = RandomNumberGenerator.new()
## Whether a caller supplied a seed or replacement generator before [method _ready].
var _generator_configured: bool


## Randomizes the default stream only when no deterministic configuration was supplied.
func _ready() -> void:
    if not _generator_configured:
        random_number_generator.randomize()


## Seeds this unit's random stream. Supplying the same seed produces the same
## sequence and resets streak protection to a clean battle state.
func set_seed(value: int) -> void:
    random_number_generator.seed = value
    _generator_configured = true
    reset_streak()


## Replaces the owned generator for deterministic simulations or specialized
## random streams. Runtime callers should usually prefer [method set_seed].
func set_random_number_generator(generator: RandomNumberGenerator) -> void:
    if not generator:
        push_error("UnitRandomizationControl requires a valid RandomNumberGenerator.")
        return
    random_number_generator = generator
    _generator_configured = true
    reset_streak()


## Clears accumulated failures.
func reset_streak() -> void:
    fails = 0


## Returns one deterministic entry from [param candidates] using this unit's
## owned random stream, or [code]null[/code] when the collection is empty.
func pick_random(candidates: Array) -> Variant:
    if candidates.is_empty():
        return null
    return candidates[random_number_generator.randi_range(0, candidates.size() - 1)]


## Publishes this manager through its parent unit's metadata lookup.
func _enter_tree() -> void:
    var parent = get_parent()
    if parent and String(name).is_valid_identifier():
        parent.set_meta(name, self)


## One attempt, with no luck/level adjustment or retries. After six failures,
## the next positive-chance roll succeeds by pity. Impossible rolls never earn pity.
func roll(roll_threshold: float) -> bool:
    var chance := clampf(roll_threshold, MIN_CHANCE, MAX_CHANCE)
    if chance <= MIN_CHANCE:
        return false
    if chance >= MAX_CHANCE:
        reset_streak()
        return true
    if fails >= FAILURE_PROTECTION:
        reset_streak()
        return true
    return percentage_roll(chance)


## Rolls against a percentage expressed on the inclusive 0-100 authoring scale.
## This raw roll tracks the shared streak but does not grant pity (used for authored proc chances).
## Boundary values are exact; intermediate values use a continuous [0, 100)
## sample so they do not inherit the old integer roll's off-by-one bias.
func percentage_roll(chance_percent: float) -> bool:
    var chance := clampf(chance_percent, MIN_CHANCE, MAX_CHANCE)
    if chance <= MIN_CHANCE:
        return false
    if chance >= MAX_CHANCE:
        fails = 0
        return true
    var success := random_number_generator.randf_range(MIN_CHANCE, MAX_CHANCE) < chance
    if success:
        fails = 0
    else:
        fails += 1
    return success
