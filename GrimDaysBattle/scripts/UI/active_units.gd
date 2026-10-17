extends SelectionUI
## Controls the active ally units ui presentation used by the battle interface.
class_name ActiveAllyUnitsUI

## Configures the template used by this active ally units ui.
@export var template: Panel

## Lookup table that stores active ui for deterministic runtime access.
var active_ui: Dictionary

## Caches dependencies and connects runtime signals after the node becomes ready.
@export var production_mode: bool = false


func _ready() -> void:
    if production_mode:
        return
    super()
    SignalBus.ally_added_to_party.connect(on_ally_added)
    SignalBus.battle_action_select.connect(on_active_unit_sent)


## Handles the ally added notification for this active ally units ui.
func on_ally_added(unit: BattleUnit) -> void:
    var duplicate_template = template.duplicate()
    duplicate_template.setup(unit)
    add_child(duplicate_template)
    active_ui.set(unit.template_resource.id, duplicate_template)


## Handles the active unit sent notification for this active ally units ui.
func on_active_unit_sent() -> void:
    for member in get_children():
        if member.unit_reference == BattleController.get_active_unit():
            member.visible = true
        else:
            member.visible = false
