# Editor configuration for skill_reset_smoke_suite.
@tool
extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/unit_skills_smoke_suite.gd"
## Exercises the real Dialogic Call boundary. Reset is not a preparation button.


class MarkerEvent:
    extends DialogicEvent
    var visits: int = 0

    func _execute() -> void:
        visits += 1


## Exercises real Dialogic reset Calls, rejects unauthorized/battle/preparation requests and
## verifies shared-point restoration preserves independent grants and cooldowns.
func run() -> void:
    assert(not Dialogic.current_timeline)
    var original_state: GameManagerStates.STATES = GameManager.state
    var party: BattlePartyManager = BattleController.party_manager
    var fixture := _fixture()
    fixture.collection.trees[0].tiers[0].maximum_stats[CombatStats.STATS.Sanity] = 100
    var template := CELINE_TEMPLATE.duplicate() as BattleUnitTemplate
    template.id = &"project_skill_reset_fixture"
    template.level = 4
    template.skill_collection = fixture.collection
    var unit := BattleUnit.create(template)
    party.add_child(unit)
    party.runtime_units[template.id] = unit
    unit.get_stat(CombatStats.STATS.Sanity).set_base(10)
    assert(unit.skills.purchase(fixture.ledger.capture().ranks, unit.skills.revision).is_empty())
    assert(unit.skills.ledger.spent_points() == 11)
    var plan := BattleSkillChainResolver.resolve(unit.skills.ledger, unit.skills.stat_values())
    var chain_id: StringName = _tip(plan, &"a3").action.id
    unit._action_cooldowns[chain_id] = 4
    assert(unit.learn_action(BASIC_ATTACK))
    unit._action_cooldowns[BASIC_ATTACK.id] = 2
    var stat := unit.get_stat(CombatStats.STATS.PhysicalResistance)
    stat.add_modifier(
        UnitStatModifier.create(
            &"story_reset_fixture", &"story:independent", stat.id, UnitStatModifier.OPERATION.FLAT_ADD, 6
        )
    )
    unit.get_stat(CombatStats.STATS.Sanity).set_base(101)
    var earned: int = unit.skills.earned_points()
    GameManager.state = GameManagerStates.STATES.Navigation
    assert(UIDirector.reset_story_skill_trees(String(template.id)) == -1)
    GameManager.state = GameManagerStates.STATES.Scenario
    assert(UIDirector.reset_story_skill_trees(String(template.id)) == -1)
    assert(party.acquire_preparation(self))
    assert((await _call_reset(template.id)).visits == 1)
    assert(unit.skills.ledger.spent_points() == 11)
    party.release_preparation(self)
    assert(party.acquire_encounter(self))
    assert((await _call_reset(template.id)).visits == 1)
    assert(unit.skills.ledger.spent_points() == 11)
    party.release_encounter(self)
    assert((await _call_reset(template.id)).visits == 1)
    assert(unit.skills.ledger.spent_points() == 0)
    assert(unit.skills.snapshot().available == earned and unit.skills.earned_points() == earned)
    assert(not unit._action_cooldowns.has(chain_id))
    assert(unit.is_action_learned(BASIC_ATTACK) and unit._action_cooldowns[BASIC_ATTACK.id] == 2)
    assert(stat.get_modifiers_from_source(&"story:independent").size() == 1)
    assert(
        UIDirector.reset_story_skill_trees(String(template.id)) == -1, "A finished Call cannot authorize a later reset."
    )
    party.runtime_units.erase(template.id)
    await free_node(unit)
    GameManager.state = original_state


## Runs a reset Call followed by a counting marker, clears the test timeline and returns the marker
## for exactly-once continuation checks.
func _call_reset(unit_id: StringName) -> MarkerEvent:
    var event := DialogicCallEvent.new()
    event.autoload_name = "UIDirector"
    event.method = "reset_story_skill_trees"
    event.arguments = [String(unit_id)]
    event.event_node_ready = true
    var marker := MarkerEvent.new()
    marker.event_node_ready = true
    Dialogic.current_timeline = DialogicTimeline.new()
    Dialogic.current_timeline_events = [event, marker]
    Dialogic.current_event_idx = -1
    Dialogic.handle_event(0)
    await get_tree().process_frame
    await Dialogic.clear()
    return marker
