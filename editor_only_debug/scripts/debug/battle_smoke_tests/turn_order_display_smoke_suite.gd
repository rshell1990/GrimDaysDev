extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"
## Checks scene-authored slots, stable identities, queued reorder and removal tweens.

const DISPLAY = preload("res://GrimDaysBattle/scenes/ui/battle/turn_order_display.tscn")


func run() -> void:
    var display := DISPLAY.instantiate() as UnitTurnOrderDisplay
    display.production_mode = true
    add_child(display)
    var units: Array[BattleUnit] = []
    for index in 5:
        units.append(create_unit(CELINE_TEMPLATE))
    display.show_order(units, 1)
    await _settle(display)
    var positions: Array[Vector2] = []
    var scales: Array[Vector2] = []
    var identities: Array[Control] = []
    var graphic: Control = display.get_node("Turn Bar Graphic")
    for index in units.size():
        var portrait: Control = display._portraits[units[index]]
        identities.append(portrait)
        positions.append(portrait.position)
        scales.append(portrait.scale)
        var visual_center: Vector2 = portrait.get_global_transform() * (portrait.size / 2)
        assert(
            is_equal_approx(visual_center.y, graphic.get_global_rect().get_center().y),
            "Every scaled portrait must stay vertically centered on the bar."
        )
    assert(positions[0].is_equal_approx(Vector2(-840, 0)))
    assert(positions[4].is_equal_approx(Vector2(710, 0)))
    assert(scales[0].is_equal_approx(Vector2.ONE))
    assert(scales[4].is_equal_approx(Vector2.ONE * 0.75))
    for index in range(1, 4):
        assert(positions[index].is_equal_approx(positions[0].lerp(positions[4], index / 4.0)))
        assert(scales[index].is_equal_approx(scales[0].lerp(scales[4], index / 4.0)))
    # Wait, then a forced delay arrives while the first animation is still running.
    var reordered: Array[BattleUnit] = [units[1], units[2], units[3], units[4], units[0]]
    display.show_order(reordered, 1)
    assert(identities[1].position == positions[1], "Reorder must tween instead of teleporting.")
    reordered = [units[1], units[3], units[2], units[4], units[0]]
    display.show_order(reordered, 1)
    await _settle(display)
    for index in reordered.size():
        var portrait: Control = display._portraits[reordered[index]]
        assert(portrait == identities[units.find(reordered[index])])
        assert(portrait.position.is_equal_approx(positions[index]))
        assert(portrait.scale.is_equal_approx(scales[index]))
    reordered.pop_front()
    display.show_order(reordered, 1)
    await _settle(display)
    for index in reordered.size():
        assert(display._portraits[reordered[index]].position.is_equal_approx(positions[index]))
        assert(display._portraits[reordered[index]].scale.is_equal_approx(scales[index]))
    assert(display._portraits.size() == 4)
    # A new round fills the fixed endpoints again, including an even unit count.
    display.show_order(reordered, 2)
    await _settle(display)
    assert(display._portraits[reordered[3]].position.is_equal_approx(positions[4]))
    assert(display._portraits[reordered[1]].position.is_equal_approx(positions[0].lerp(positions[4], 1.0 / 3)))
    var single: Array[BattleUnit] = [units[0]]
    display.show_order(single, 3)
    await _settle(display)
    assert(display._portraits[units[0]].position.is_equal_approx(positions[0]))
    display.show_order(units, 4)
    var empty: Array[BattleUnit] = []
    display.show_order(empty)
    await get_tree().process_frame
    assert(display._portraits.is_empty() and display._snapshots.is_empty())
    await free_node(display)
    for unit in units:
        await free_node(unit)


func _settle(display: UnitTurnOrderDisplay) -> void:
    for attempt in 100:
        if display._snapshots.is_empty() and not display._order_tween.is_running():
            return
        await get_tree().create_timer(0.05).timeout
    assert(false, "Turn-order animation did not settle.")
