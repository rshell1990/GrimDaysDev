extends RefCounted
## Presentation boundary used by battle orchestration. The default implementation
## deliberately completes every request without creating scene-tree presentation.
class_name BattlePresentationAdapter


## Deploys an optional visual representation for a combatant.
func deploy_unit(_template: BattleUnitTemplate, _team_id: StringName) -> Unit2DDisplay:
    return null


## Returns the visual representation currently associated with a combatant.
func get_unit_display(_unit: BattleUnit) -> Unit2DDisplay:
    return null


## Releases every battle-owned presentation node.
func clear() -> void:
    pass


## Reports whether this adapter owns visual scene-tree presentation.
func is_visual() -> bool:
    return false
