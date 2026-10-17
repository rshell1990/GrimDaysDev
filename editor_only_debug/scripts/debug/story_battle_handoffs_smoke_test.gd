## Runs the existing encounter handoff suites without the unrelated full combat suite.
extends Node

const SUITES: Array[Script] = [
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/courtyard_story_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/basement_story_smoke_suite.gd")
]


func _ready() -> void:
    _run.call_deferred()


func _run() -> void:
    Dialogic.Text.text_finished.disconnect(SystemHeadquarters._on_text_finished)
    for script: Script in SUITES:
        var suite: Node = script.new()
        add_child(suite)
        await suite.run()
        suite.queue_free()
        await get_tree().process_frame
        print( # lint:ignore debug-print -- Required test/CLI output.
            "STORY_SUITE_COMPLETE: " + script.resource_path.get_file()
        )
    GameManager.on_loading_sequence_start()
    await Dialogic.clear()
    await get_tree().create_timer(0.5).timeout
    Dialogic.Text.text_finished.connect(SystemHeadquarters._on_text_finished)
    print("STORY_BATTLE_HANDOFFS_SMOKE_TEST: PASS") # lint:ignore debug-print -- Required test/CLI output.
    get_tree().quit()
