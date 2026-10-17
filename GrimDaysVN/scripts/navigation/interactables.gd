extends Node3D


## When the node is ready, this function connects responses to
## [code]Dialogic.timeline_started[/code], [code]Dialogic.timeline_ended[/code].
func _ready() -> void:
    Dialogic.timeline_started.connect(on_timeline_start)
    Dialogic.timeline_ended.connect(on_timeline_end)


## Currently performs no work; this function is a placeholder for behavior supplied later or by a
## child script.
func on_timeline_start() -> void:
    #visible = false
    pass


## Currently performs no work; this function is a placeholder for behavior supplied later or by a
## child script.
func on_timeline_end() -> void:
    #visible = true
    pass
