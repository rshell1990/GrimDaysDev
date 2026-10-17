extends SelectionUI
## Controls the battle action selector presentation used by the battle interface.
class_name BattleActionSelector
## Configures the turn order displayer used by this action selector.
@export var turn_order_displayer: UnitTurnOrderDisplay
## Configures the skill template used by this action selector.
@export var skill_template: ActionTemplate
## Configures the targeting cursor used by this action selector.
@export var targeting_cursor: Texture2D
## Runtime active ally state used by this action selector.
var active_ally: BattleUnit
## Whether the pressed condition currently holds.
var pressed: bool


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    super()
    SignalBus.send_active_unit.connect(on_active_unit_sent)


## Handles the active unit sent notification for this action selector.
func on_active_unit_sent(unit: BattleUnit) -> void:
    if unit not in %"Battle Controller".ally_unit_holder.get_children():
        return
    active_ally = unit


## Handles the attack pressed notification for this action selector.
func _on_attack_pressed() -> void:
    if pressed:
        return
    CustomLogger.confirm(self, _on_attack_pressed, "Attack pressed!", CustomLogger.LEVEL.SEVERE)
    var active_unit: BattleUnit = BattleController.get_active_unit()
    var action: ActionTemplate = active_unit.get_basic_action() if active_unit else null
    if not active_unit or not active_unit.can_use_action(action, true):
        return
    pressed = true
    BattleController.pass_cargo_to_current_phase({"action": action})
    var select_target: Image = targeting_cursor.get_image()
    select_target.resize(64, 64)
    Input.set_custom_mouse_cursor(select_target)
    SignalBus.battle_action_selected.emit()
    await get_tree().create_timer(0.1).timeout
    pressed = false
