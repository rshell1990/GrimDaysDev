# Isolated entry point for authored Street Bullies and default assignment verification.
extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/street_bullies_smoke_suite.gd"


func _ready() -> void:
    await run()
    print("STREET_BULLIES_SMOKE_TEST: PASS") # lint:ignore debug-print -- Required test/CLI output.
