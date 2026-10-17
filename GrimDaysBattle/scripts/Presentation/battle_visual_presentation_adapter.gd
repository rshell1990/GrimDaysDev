extends BattlePresentationAdapter
## Scene-backed presentation adapter for the existing visual battle layer.
class_name BattleVisualPresentationAdapter

## Scene-tree holder that owns allied combatant displays.
var ally_holder: Unit2DParty
## Scene-tree holder that owns opposing combatant displays.
var foe_holder: Unit2DParty
## Placement boundary forwarded to newly created unit displays.
var camera_bounds: CollisionShape2D


## Creates an adapter over the supplied scene nodes. All dependencies are
## optional so an incomplete visual scene fails deployment without crashing.
func _init(
    allies: Unit2DParty = null,
    foes: Unit2DParty = null,
    bounds: CollisionShape2D = null,
) -> void:
    ally_holder = allies
    foe_holder = foes
    camera_bounds = bounds


## Creates one display under the holder selected by [param team_id]. Returns
## [code]null[/code] when the team or required visual dependencies are absent.
func deploy_unit(template: BattleUnitTemplate, team_id: StringName) -> Unit2DDisplay:
    var holder := _holder_for_team(team_id)
    if not is_instance_valid(holder) or not is_instance_valid(camera_bounds):
        return null
    var previous_count := holder.get_child_count()
    holder.add_to_party(template, camera_bounds)
    if holder.get_child_count() <= previous_count:
        return null
    return holder.get_child(holder.get_child_count() - 1) as Unit2DDisplay


## Finds the display bound to [param unit] across both visual team holders.
func get_unit_display(unit: BattleUnit) -> Unit2DDisplay:
    for holder in [ally_holder, foe_holder]:
        if not is_instance_valid(holder):
            continue
        for child in holder.get_children():
            var display := child as Unit2DDisplay
            if display and display.unit_reference == unit:
                return display
    return null


## Detaches and schedules every battle-owned unit display for deletion.
func clear() -> void:
    for holder in [ally_holder, foe_holder]:
        if not is_instance_valid(holder):
            continue
        for child in holder.get_children():
            holder.remove_child(child)
            child.queue_free()


## Reports that this adapter owns scene-tree presentation.
func is_visual() -> bool:
    return true


## Maps the canonical [code]allies[/code] and [code]foes[/code] team IDs to
## their visual holders. Unknown team IDs deliberately have no holder.
func _holder_for_team(team_id: StringName) -> Unit2DParty:
    if team_id == &"allies":
        return ally_holder
    if team_id == &"foes":
        return foe_holder
    return null
