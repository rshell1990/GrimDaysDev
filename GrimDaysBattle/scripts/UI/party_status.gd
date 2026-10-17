extends SelectionUI
## Controls the party status ui presentation used by the battle interface.
class_name PartyStatusUI

## Configures the template used by this party status ui.
@export var template: Panel

## Lookup table that stores party ui for deterministic runtime access.
var party_ui: Dictionary

## Caches dependencies and connects runtime signals after the node becomes ready.
@export var production_mode: bool = false


func _ready() -> void:
    if production_mode:
        return
    super()
    SignalBus.ally_added_to_party.connect(on_ally_added)
    SignalBus.battle_action_select.connect(on_active_unit_sent)


## Handles the ally added notification for this party status ui.
func on_ally_added(unit: BattleUnit) -> void:
    var duplicate_template = template.duplicate()
    duplicate_template.setup(unit)
    get_child(0).add_child(duplicate_template)
    party_ui.set(unit.template_resource.id, duplicate_template)
    duplicate_template.visible = true


## Handles the active unit sent notification for this party status ui.
func on_active_unit_sent() -> void:
    var unit = BattleController.get_active_unit()
    var failures: int = 0
    var member_holder = get_child(0)
    for x in range(0, member_holder.get_children().size()):
        if member_holder.get_child(x).unit_reference != unit:
            failures += 1

    if failures == member_holder.get_children().size():
        return

    for member in member_holder.get_children():
        if member.unit_reference == unit:
            member.visible = false
        elif member.unit_reference != null:
            member.visible = true
