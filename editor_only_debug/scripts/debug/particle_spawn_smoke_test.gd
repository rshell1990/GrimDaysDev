# Runs focused particle presentation and action-targeting regression checks.
extends Node

const SUITES: Array[Script] = [
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/presentation_effect_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/production_visual_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/action_trigger_routing_smoke_suite.gd"),
]

var completed: bool = false


func _ready() -> void:
    await get_tree().process_frame
    for suite_script in SUITES:
        var suite: Node = suite_script.new()
        add_child(suite)
        await suite.run()
        suite.queue_free()
        await suite.tree_exited
        print("PARTICLE_SUITE_PASS: ", suite_script.resource_path.get_file()) # lint:ignore debug-print,line-length -- Required test/CLI output.
    completed = true
    print("PARTICLE_SPAWN_SMOKE_TEST: PASS") # lint:ignore debug-print -- Required test/CLI output.
