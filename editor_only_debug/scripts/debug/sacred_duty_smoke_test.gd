# Isolated entry point for the nun tree and both basement story outcomes.
extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/sacred_duty_smoke_suite.gd"

const STORY_SUITE = preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/basement_story_smoke_suite.gd")


func _ready() -> void:
    await run()
    var story := STORY_SUITE.new()
    add_child(story)
    await story.run()
    await free_node(story)
    print("SACRED_DUTY_SMOKE_TEST: PASS") # lint:ignore debug-print -- Required test/CLI output.
