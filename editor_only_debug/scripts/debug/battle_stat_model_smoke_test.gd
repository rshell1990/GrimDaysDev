extends Node

## Printed after all suites finish without stopping at a failed assertion.
const SUCCESS_MESSAGE := "BATTLE_STAT_MODEL_SMOKE_TEST: PASS"
## Battle checks run in order, covering combat rules, story integration and displays.
const SUITES: Array[Script] = [
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/sacred_duty_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/basement_story_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/street_bullies_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/combat_authoring_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/stun_flow_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/effect_stacking_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/effect_expiry_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/retained_override_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/action_rank_progression_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/target_substitution_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/turn_order_display_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/production_ui_commands_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/skill_node_strategy_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/targeted_reaction_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/lifecycle_damage_reaction_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/authored_hit_proc_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/damage_reaction_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/lucidity_madness_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/per_effect_hit_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/turn_delay_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/skill_reset_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/skill_preparation_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/unit_skills_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/skill_chain_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/skill_investment_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/attribute_progression_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/stat_state_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/encounter_state_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/action_trigger_routing_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/production_story_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/courtyard_story_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/post_battle_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/production_flow_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/production_visual_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/production_encounter_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/construction_randomization_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/runtime_party_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/party_preparation_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/skill_tree_integration_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/stat_model_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/effect_lifecycle_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/damage_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/resource_effect_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/intrinsic_effect_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/ownership_override_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/effect_chain_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/presentation_effect_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/action_resolution_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/phase_action_resolution_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/defeat_phase_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/round_effect_defeat_phase_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/headless_battle_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_result_integration_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/action_equipment_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/inventory_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/consumable_action_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/status_bomb_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_flow_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/hud_smoke_suite.gd"),
]


## Runs each suite and waits for its checks to finish. Removes that suite before starting the
## next one, then prints the success message. The scene stays open for log inspection.
func _ready() -> void:
    await get_tree().process_frame
    for suite_script in SUITES:
        print("BATTLE_SUITE_START: " + suite_script.resource_path.get_file()) # lint:ignore debug-print,line-length -- Required test/CLI output.
        var suite: Node = suite_script.new()
        add_child(suite)
        await suite.run()
        suite.queue_free()
        await suite.tree_exited
        print("BATTLE_SUITE_COMPLETE: " + suite_script.resource_path.get_file()) # lint:ignore debug-print,line-length -- Required test/CLI output.
    print(SUCCESS_MESSAGE) # lint:ignore debug-print -- Required test/CLI output.
