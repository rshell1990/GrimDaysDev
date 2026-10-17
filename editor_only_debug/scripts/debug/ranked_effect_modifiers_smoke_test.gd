# Focused progression verification independent of unfinished authored skill-tree payloads.
extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/combat_authoring_smoke_suite.gd"


func _ready() -> void:
    await _test_ranked_combat_modifiers()
    print("RANKED_EFFECT_MODIFIERS_SMOKE_TEST: PASS") # lint:ignore debug-print -- Required test/CLI output.


func _fixture(count: int = 1) -> Dictionary:
    # Duplicate only the template and omit progression content irrelevant to these combat checks.
    var template := CELINE_TEMPLATE.duplicate() as BattleUnitTemplate
    template.skill_collection = null
    var party := IsolatedParty.new()
    add_child(party)
    var actor := BattleUnit.create(template)
    party.add_child(actor)
    party.runtime_units[template.id] = actor
    party.active_party_ids = [template.id]
    var templates: Array[BattleUnitTemplate] = []
    for index in count:
        templates.append(template)
    var scene: BattleEncounterScene = ENCOUNTER.instantiate()
    add_child(scene)
    assert(scene.begin_encounter(party, templates, &"ranked_modifiers", 515))
    scene.flow.stop()
    for unit in scene.coordinator.roster.get_participants():
        for stat in [CombatStats.STATS.Health, CombatStats.STATS.Mana, CombatStats.STATS.Energy]:
            unit.get_stat(stat).add_modifier(
                UnitStatModifier.create(
                    StringName("ranked_fixture:%s" % stat),
                    &"test:ranked_fixture",
                    stat,
                    UnitStatModifier.OPERATION.OVERRIDE,
                    100
                )
            )
            unit.get_stat(stat).restore_current(100)
    var resolver := BattleActionResolver.new()
    add_child(resolver)
    return {
        "scene": scene,
        "actor": actor,
        "foes": scene.coordinator.roster.get_foes(),
        "party": party,
        "resolver": resolver
    }
