## Focused, save-free runner for all eight authored status-effect bombs.
extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/status_bomb_smoke_suite.gd"

const RELATED_SUITES: Array[Script] = [
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/consumable_action_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/stun_flow_smoke_suite.gd"),
]


func _ready() -> void:
    get_tree().create_timer(60.0).timeout.connect(_on_timeout)
    _run.call_deferred()


func _run() -> void:
    await run()
    if completed_bombs != BOMBS.size():
        push_error("STATUS_BOMBS_SMOKE_TEST: failed before all eight bombs completed.")
        get_tree().quit(1)
        return
    for script: Script in RELATED_SUITES:
        var suite: Node = script.new()
        add_child(suite)
        await suite.run()
        await free_node(suite)
        print("BOMB_REGRESSION_COMPLETE: " + script.resource_path.get_file()) # lint:ignore debug-print,line-length -- Required test/CLI output.
    GameManager.on_loading_sequence_start()
    await get_tree().create_timer(0.5).timeout
    print("STATUS_BOMBS_SMOKE_TEST: PASS (8 bombs)") # lint:ignore debug-print -- Required test/CLI output.
    get_tree().quit()


func _on_timeout() -> void:
    push_error("STATUS_BOMBS_SMOKE_TEST: timed out.")
    get_tree().quit(1)
