extends Node
## Runs in editor and release exports. Checks must execute without debug-only assertions.

const UNIT_PATHS = [
    "res://GrimDaysBattle/resources/units/celine_teen/celine_battle_unit_template.tres",
    "res://GrimDaysBattle/resources/units/harlok/harlok_battle_unit_template.tres",
    "res://GrimDaysBattle/resources/units/goon_a/goon_a_battle_unit_template.tres",
    "res://GrimDaysBattle/resources/units/goon_b/goon_b_battle_unit_template.tres",
]

var failures: int = 0


func _ready() -> void:
    await get_tree().process_frame
    var party: BattlePartyManager = BattleController.party_manager
    _check(party != null and party.runtime_units.has(&"CelineTeen"), "Permanent Celine was not created at startup.")
    for path in UNIT_PATHS:
        # Dynamic loads exercise resources as packaged, including export remapping.
        var template := load(path) as BattleUnitTemplate # lint:ignore load-in-var,line-length -- Load fixtures during test execution.
        if not _check(template != null, "Missing unit template: " + path):
            continue
        var errors := BattleUnitTemplateValidator.validate(template)
        if not _check(errors.is_empty(), "%s: %s" % [template.id, "; ".join(errors)]):
            continue
        var unit := BattleUnit.create(template)
        if not _check(unit != null, "Could not create " + String(template.id)):
            continue
        add_child(unit)
        _check(BattleUnitTemplateValidator.validate_runtime(unit).is_empty(), "Invalid runtime stats: " + path)
        _check(unit.inventory != null and unit.skills != null, "Missing inventory or skill adapter: " + path)
        for stat_id in [CombatStats.STATS.Health, CombatStats.STATS.Energy]:
            var stat := unit.get_stat(stat_id)
            _check(stat != null and stat.Max > 0 and stat.Current == stat.Max, "Invalid starting pool: " + path)
        unit.queue_free()
        await unit.tree_exited
    print( # lint:ignore debug-print -- Required test/CLI output.
        (
            "EXPORT_CHARACTER_CREATION_SMOKE_TEST: %s (%s)"
            % ["PASS" if failures == 0 else "FAIL", "debug" if OS.is_debug_build() else "release"]
        )
    )
    get_tree().quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> bool:
    if not condition:
        failures += 1
        push_error(message)
    return condition
