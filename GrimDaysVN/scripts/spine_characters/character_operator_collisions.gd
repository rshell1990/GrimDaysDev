extends Area3D

## Notification for enter. Supplies [code]owner[/code], [code]other[/code] to connected functions.
signal enter(owner, other)
## Notification for exit. Supplies [code]other[/code] to connected functions.
signal exit(other)
## Character object controlled or observed by this helper.
var character: CharacterOperator


## When the node is ready, this function sets [code]character[/code] to [code]get_parent()[/code].
func _ready():
    character = get_parent()
    character.listen_for(enter, character.on_area_entered)
    character.listen_for(exit, character.on_area_exited)


## Sends [code]enter[/code] notifications.
func _on_collision_entered(area: Area3D) -> void:
    var hit = area.get_parent() as CharacterOperator
    enter.emit(character, hit)


## Sends [code]exit[/code] notifications.
func _on_collision_exited(area: Area3D) -> void:
    var hit = area.get_parent() as CharacterOperator
    exit.emit(hit)
