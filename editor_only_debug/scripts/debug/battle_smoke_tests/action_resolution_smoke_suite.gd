extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"

## Script loaded for action request script; reused instead of looking up the file on each call.
const ACTION_REQUEST_SCRIPT := preload(
    "res://GrimDaysBattle/scripts/Actions/Runtime/battle_action_request.gd"
)
## Script loaded for action resolver script; reused instead of looking up the file on each call.
const ACTION_RESOLVER_SCRIPT := preload(
    "res://GrimDaysBattle/scripts/Actions/Runtime/battle_action_resolver.gd"
)
## Script loaded for combat event script; reused instead of looking up the file on each call.
const COMBAT_EVENT_SCRIPT := preload("res://GrimDaysBattle/scripts/Actions/Runtime/battle_combat_event.gd")


## Runs the action resolution smoke checks. Creates or uses test objects and stops on failed
## assertions.
func run() -> void:
    var arena := Node.new()
    var allies := Node.new()
    var foes := Node.new()
    allies.name = "Allies"
    foes.name = "Foes"
    arena.add_child(allies)
    arena.add_child(foes)
    add_child(arena)
    var actor := BattleUnit.create(CELINE_TEMPLATE)
    var target := BattleUnit.create(CELINE_TEMPLATE)
    allies.add_child(actor)
    foes.add_child(target)
    actor.randomizer.set_seed(1001)
    target.randomizer.set_seed(2002)
    _set_override(actor, CombatStats.STATS.Accuracy, 100.0, &"resolver_accuracy")
    _set_override(actor, CombatStats.STATS.CriticalStrike, 0.0, &"resolver_critical")
    _set_override(actor, CombatStats.STATS.PhysicalDamage, 10.0, &"resolver_damage")
    _set_override(target, CombatStats.STATS.Evasion, 0.0, &"resolver_evasion")
    _set_override(target, CombatStats.STATS.LuckyEvasion, 0.0, &"resolver_lucky_evasion")
    _set_override(target, CombatStats.STATS.PhysicalResistance, 0.0, &"resolver_resistance")

    var resolver: Node = ACTION_RESOLVER_SCRIPT.new()
    add_child(resolver)
    await _test_hit_resolution(resolver, actor, target)
    await get_tree().process_frame
    await _test_critical_resolution(resolver, actor, target)
    await get_tree().process_frame
    await _test_miss_resolution(resolver, actor, target)
    await _test_request_validation(resolver, actor, target)
    await free_node(resolver)
    await free_node(arena)


## Checks hit resolution using test objects and assertions. A failed assertion identifies behavior
## that no longer meets the test’s expectation.
func _test_hit_resolution(resolver: Node, actor: BattleUnit, target: BattleUnit) -> void:
    actor.randomizer.set_seed(2468)
    var expected_rng := RandomNumberGenerator.new()
    expected_rng.seed = 2468
    var expected_damage := roundf(10.0 * expected_rng.randf_range(0.85, 1.15))
    var supplied_targets: Array[BattleUnit] = [target]
    var request = ACTION_REQUEST_SCRIPT.new(&"resolver_hit", actor, BASIC_ATTACK, supplied_targets)
    supplied_targets.clear()
    assert(request.targets == [target], "ActionRequest must retain an immutable copy of selected targets.")
    var old_health := target.get_stat(CombatStats.STATS.Health).Current
    var resolution = await resolver.resolve(request)
    assert(resolution.success, resolution.error)
    assert(resolution.get_events(COMBAT_EVENT_SCRIPT.TYPE.ACTION_STARTED).size() == 1)
    assert(resolution.get_events(COMBAT_EVENT_SCRIPT.TYPE.HIT).size() == 1)
    assert(resolution.get_events(COMBAT_EVENT_SCRIPT.TYPE.MISS).is_empty())
    var damage_events: Array = resolution.get_events(COMBAT_EVENT_SCRIPT.TYPE.DAMAGE)
    assert(damage_events.size() == 1, "Basic Attack must produce exactly one authoritative damage event.")
    assert(is_equal_approx(damage_events[0].amount, expected_damage))
    assert(is_equal_approx(target.get_stat(CombatStats.STATS.Health).Current, old_health - expected_damage))
    assert(resolution.get_events(COMBAT_EVENT_SCRIPT.TYPE.ACTION_FINISHED).size() == 1)


## Checks critical resolution using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_critical_resolution(resolver: Node, actor: BattleUnit, target: BattleUnit) -> void:
    actor.randomizer.set_seed(2468)
    var expected_rng := RandomNumberGenerator.new()
    expected_rng.seed = 2468
    var expected_damage := roundf(20.0 * expected_rng.randf_range(0.85, 1.15))
    _set_override(actor, CombatStats.STATS.CriticalStrike, 100.0, &"resolver_critical")
    var old_health := target.get_stat(CombatStats.STATS.Health).Current
    var request = ACTION_REQUEST_SCRIPT.new(&"resolver_critical", actor, BASIC_ATTACK, [target])
    var resolution = await resolver.resolve(request)
    assert(resolution.success, resolution.error)
    var critical_events: Array = resolution.get_events(COMBAT_EVENT_SCRIPT.TYPE.CRITICAL)
    assert(critical_events.size() == 1, "A guaranteed critical must produce one correlated event.")
    assert(is_equal_approx(critical_events[0].amount, expected_damage))
    assert(critical_events[0].data.get("effect_id") == &"basic_physical_damage")
    var damage_events: Array = resolution.get_events(COMBAT_EVENT_SCRIPT.TYPE.DAMAGE)
    assert(damage_events.size() == 1)
    assert(is_equal_approx(damage_events[0].amount, expected_damage))
    assert(is_equal_approx(target.get_stat(CombatStats.STATS.Health).Current, old_health - expected_damage))
    _set_override(actor, CombatStats.STATS.CriticalStrike, 0.0, &"resolver_critical")
    var health: UnitGenericStat = target.get_stat(CombatStats.STATS.Health)
    health.increase_current_flat(health.Max)


## Checks miss resolution using test objects and assertions. A failed assertion identifies behavior
## that no longer meets the test’s expectation.
func _test_miss_resolution(resolver: Node, actor: BattleUnit, target: BattleUnit) -> void:
    _set_override(actor, CombatStats.STATS.Accuracy, 0.0, &"resolver_accuracy")
    var old_health := target.get_stat(CombatStats.STATS.Health).Current
    var request = ACTION_REQUEST_SCRIPT.new(&"resolver_miss", actor, BASIC_ATTACK, [target])
    var resolution = await resolver.resolve(request)
    assert(resolution.success, resolution.error)
    assert(resolution.get_events(COMBAT_EVENT_SCRIPT.TYPE.HIT).is_empty())
    assert(resolution.get_events(COMBAT_EVENT_SCRIPT.TYPE.MISS).size() == 1)
    assert(resolution.get_events(COMBAT_EVENT_SCRIPT.TYPE.DAMAGE).is_empty())
    assert(is_equal_approx(target.get_stat(CombatStats.STATS.Health).Current, old_health))
    assert(resolution.get_events(COMBAT_EVENT_SCRIPT.TYPE.ACTION_FINISHED).size() == 1)


## Checks request validation using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_request_validation(resolver: Node, actor: BattleUnit, target: BattleUnit) -> void:
    var request = ACTION_REQUEST_SCRIPT.new(&"resolver_duplicate", actor, BASIC_ATTACK, [target, target])
    var resolution = await resolver.resolve(request)
    assert(not resolution.success)
    assert("duplicate" in resolution.error.to_lower() or "target limit" in resolution.error.to_lower())
    assert(resolution.events.is_empty(), "Rejected requests must not emit or mutate combat events.")


## Adds a test-only stat adjustment that replaces the selected stat's value with the supplied
## amount.
func _set_override(
    unit: BattleUnit,
    stat_type: CombatStats.STATS,
    amount: float,
    modifier_id: StringName,
) -> void:
    (
        unit
        . get_stat(stat_type)
        . add_modifier(
            (
                UnitStatModifier
                . create(
                    modifier_id,
                    &"test:action_resolver",
                    stat_type,
                    UnitStatModifier.OPERATION.OVERRIDE,
                    amount,
                )
            )
        )
    )
