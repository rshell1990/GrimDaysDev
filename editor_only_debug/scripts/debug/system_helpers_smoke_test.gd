## Checks command parsing and diagnostic output without changing game or save state.
extends Node


func _ready() -> void:
    _run.call_deferred()


func _run() -> void:
    assert(SystemHelpers.args_to_dict([]).is_empty())
    var parsed: Dictionary = SystemHelpers.args_to_dict(
        ["move", " Name :Gerano", "path:res://GrimDaysVN/example.tscn", "time:12:30", "empty:", "text: padded "]
    )
    assert(parsed == {
        "name": "Gerano", "path": "res://GrimDaysVN/example.tscn",
        "time": "12:30", "empty": "", "text": " padded "
    })
    assert(SystemHelpers.args_to_dict(PackedStringArray(["NAME:first", "name:last"])) == {"name": "last"})
    assert(SystemHelpers.args_to_dict([&"name:Hamun"]) == {"name": "Hamun"})
    assert(SystemHelpers.args_to_dict([":invalid", 42, "name:Novaras"]) == {"name": "Novaras"})
    assert(SystemHelpers.args_to_dict(null).is_empty())
    SystemHelpers.print("SYSTEM_HELPERS_PLAIN:", 1, ":", 2)
    SystemHelpers.print_rich("[b]SYSTEM_HELPERS_RICH:[/b]", 3, ":", 4)
    print("SYSTEM_HELPERS_NESTED_BEGIN") # lint:ignore debug-print -- Required test/CLI output.
    SystemHelpers.pretty_print_dict({"items": [{"label": "nested-leaf"}, ["array-leaf", ["deep-leaf"]], null]}, 2)
    print("SYSTEM_HELPERS_NESTED_END") # lint:ignore debug-print -- Required test/CLI output.
    SystemHelpers.pretty_print_dict({}, -1)
    print("SYSTEM_HELPERS_SMOKE_TEST: PASS") # lint:ignore debug-print -- Required test/CLI output.
    get_tree().quit()
