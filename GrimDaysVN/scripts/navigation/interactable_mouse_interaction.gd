extends Node
## Runs separate helpers when the pointer enters or leaves an interaction.
class_name MouseInteraction

## Scene object used for enter function.
var enter_function: Node
## Scene object used for exit function.
var exit_function: Node


## When the node is ready, this function connects responses to
## [code]Dialogic.timeline_started[/code]; sets [code]enter_function[/code] to
## [code]get_child(0)[/code]; sets [code]exit_function[/code] to [code]get_child(1)[/code].
func _ready():
    if get_child_count() < 2:
        SystemHelpers.print_rich("[b][color=#F77]", name, " missing nodes.")
    enter_function = get_child(0)
    exit_function = get_child(1)
    Dialogic.timeline_started.connect(on_exit)


## Runs the configured pointer-entry helper.
func on_enter():
    enter_function.execute()


## Runs the configured pointer-exit helper.
func on_exit():
    exit_function.execute()
