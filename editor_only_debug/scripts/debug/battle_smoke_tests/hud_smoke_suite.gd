extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"

## Script loaded for resource display script; reused instead of looking up the file on each call.
const RESOURCE_DISPLAY_SCRIPT := preload("res://GrimDaysBattle/scripts/UI/resource_display.gd")


## Runs the hud smoke checks. Creates or uses test objects and stops on failed assertions.
func run() -> void:
    _test_zero_safe_resource_ratios()
    await _test_overview_resource_display()
    await _test_unit_status_bar()


## Checks zero safe resource ratios using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_zero_safe_resource_ratios() -> void:
    var unit := create_unit(CELINE_TEMPLATE)
    var empty_health := create_flat_stat(unit, CombatStats.STATS.Health, 0.0)
    assert(is_zero_approx(empty_health.ratio), "An empty zero-max resource must have a safe zero ratio.")
    assert(is_zero_approx(empty_health.percentage), "An empty zero-max resource must have a safe zero percentage.")
    unit.queue_free()


## Checks overview resource display using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_overview_resource_display() -> void:
    var display: TextureProgressBar = _create_resource_display()
    add_child(display)
    var first_unit := create_unit(CELINE_TEMPLATE)
    var first_health := create_flat_stat(first_unit, CombatStats.STATS.Health, 100.0)
    display.call(&"bind_resource", first_health)
    assert(is_equal_approx(display.max_value, 100.0))
    assert(is_equal_approx(display.value, 100.0))

    first_health.decrease_current_flat(25.0)
    assert(_current_text(display) == "75", "The overview must immediately display damage results.")
    await get_tree().create_timer(AnimationTimes.FAST + 0.05).timeout
    assert(is_equal_approx(display.value, 75.0), "The overview bar must animate to the current value, not the delta.")

    first_health.increase_current_flat(10.0)
    assert(_current_text(display) == "85", "The overview must display healing results.")
    await get_tree().create_timer(AnimationTimes.FAST + 0.05).timeout
    assert(is_equal_approx(display.value, 85.0))

    var second_unit := create_unit(CELINE_TEMPLATE)
    var second_health := create_flat_stat(second_unit, CombatStats.STATS.Health, 40.0)
    display.call(&"bind_resource", second_health)
    assert(
        not first_health.value_changed.is_connected(Callable(display, &"on_resource_change")),
        "Rebinding must disconnect the old resource."
    )
    first_health.decrease_current_flat(10.0)
    assert(_current_text(display) == "40", "An old unit must not update a rebound overview.")
    second_health.decrease_current_flat(15.0)
    assert(_current_text(display) == "25", "A rebound overview must listen to the new unit.")

    await free_node(display)
    await free_node(first_unit)
    await free_node(second_unit)


## Checks unit status bar using test objects and assertions. A failed assertion identifies behavior
## that no longer meets the test’s expectation.
func _test_unit_status_bar() -> void:
    var status_bar := UnitStatusBar.new()
    var name_label := Label.new()
    var health_bar := TextureProgressBar.new()
    status_bar.add_child(name_label)
    status_bar.add_child(health_bar)
    status_bar.name_label = name_label
    status_bar.health_bar = health_bar
    add_child(status_bar)

    var first_unit := create_unit(CELINE_TEMPLATE)
    var first_health := create_flat_stat(first_unit, CombatStats.STATS.Health, 100.0)
    status_bar.initialize(first_unit)
    assert(is_equal_approx(health_bar.max_value, 1.0))
    assert(is_equal_approx(health_bar.value, 1.0))
    first_health.decrease_current_flat(50.0)
    await status_bar.active_tweens.back().finished
    await get_tree().process_frame
    assert(
        is_equal_approx(health_bar.value, 0.5),
        (
            "The status bar must animate to the health ratio; got %s from ratio %s."
            % [health_bar.value, first_health.ratio]
        ),
    )

    var second_unit := create_unit(CELINE_TEMPLATE)
    var second_health := create_flat_stat(second_unit, CombatStats.STATS.Health, 40.0)
    status_bar.initialize(second_unit)
    assert(
        not first_health.value_changed.is_connected(status_bar.on_health_resource_change),
        "Rebinding must disconnect the old health stat."
    )
    first_health.decrease_current_flat(20.0)
    assert(is_equal_approx(health_bar.value, 1.0), "An old unit must not update a rebound status bar.")
    second_health.decrease_current_flat(20.0)
    await status_bar.active_tweens.back().finished
    await get_tree().process_frame
    assert(is_equal_approx(health_bar.value, 0.5), "A rebound status bar must listen to the new unit.")

    await free_node(status_bar)
    await free_node(first_unit)
    await free_node(second_unit)


## Adds [code]margin[/code] as a child of [code]display[/code]; adds [code]row[/code] as a child of
## [code]margin[/code]; sets [code]margin.name[/code] to [code]"MarginContainer"[/code]. It also
## sets [code]row.name[/code] to [code]"HBoxContainer"[/code]. Returns [code]display[/code].
func _create_resource_display() -> TextureProgressBar:
    var display: TextureProgressBar = RESOURCE_DISPLAY_SCRIPT.new()
    var margin := MarginContainer.new()
    margin.name = "MarginContainer"
    display.add_child(margin)
    var row := HBoxContainer.new()
    row.name = "HBoxContainer"
    margin.add_child(row)
    _add_layered_label(row, "Current", "Current2")
    _add_layered_label(row, "Max", "Max2")
    return display


## Adds [code]outer[/code] as a child of [code]parent[/code]; adds [code]inner[/code] as a child of
## [code]outer[/code]; sets [code]outer.name[/code] to [code]outer_name[/code]. It also sets
## [code]inner.name[/code] to [code]inner_name[/code].
func _add_layered_label(parent: Node, outer_name: String, inner_name: String) -> void:
    var outer := Label.new()
    outer.name = outer_name
    parent.add_child(outer)
    var inner := Label.new()
    inner.name = inner_name
    outer.add_child(inner)


## Returns the currently displayed text from the test control.
func _current_text(display: TextureProgressBar) -> String:
    return display.get_node("MarginContainer/HBoxContainer/Current").text
