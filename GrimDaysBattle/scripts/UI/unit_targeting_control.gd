extends Control
## Controls the unit targeting controller presentation used by the battle interface.
class_name UnitTargetingController

## Notification for target added. Supplies [code]unit[/code] to connected functions.
signal target_added(unit: BattleUnit)
## Notification for target removed. Supplies [code]unit[/code] to connected functions.
signal target_removed(unit: BattleUnit)
## Whether target selection uses the older game-wide notifications. Copies this setting from the
## unit's display when ready.
var use_global_selection: bool = true

## Cached reference to the mouse trigger node, resolved when this node becomes ready.
@onready var mouse_trigger: Control = $"../Mouse Trigger"
## Configures the highlighted symbol used by this unit targeting controller.
@export var highlighted_symbol: Dictionary[CombatActions.TYPE, TextureRect]
## Runtime skill selected state used by this unit targeting controller.
var skill_selected: ActionTemplate
## Whether the highlighted condition currently holds.
var highlighted: bool = false
##
## Runtime unit reference state used by this unit targeting controller.
var unit_reference: BattleUnit:
    get:
        return get_parent().get_parent().unit_reference


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    use_global_selection = get_parent().get_parent().use_global_battle_navigation
    mouse_trigger.mouse_entered.connect(_on_mouse_trigger_mouse_entered)
    mouse_trigger.mouse_exited.connect(_on_mouse_trigger_mouse_exited)
    mouse_trigger.gui_input.connect(_on_gui_input)
    if use_global_selection:
        SignalBus.target_selected.connect(hide_symbols)


## Handles the mouse trigger mouse entered notification for this unit targeting controller.
func _on_mouse_trigger_mouse_entered() -> void:
    CustomLogger.hint(
        self, _on_mouse_trigger_mouse_entered, "Target mouse region entered.", CustomLogger.LEVEL.VERY_VERBOSE
    )
    if not skill_selected:
        return
    show_symbol(1.0)
    highlighted = true


## Handles the mouse trigger mouse exited notification for this unit targeting controller.
func _on_mouse_trigger_mouse_exited() -> void:
    if not skill_selected:
        return
    show_symbol()
    highlighted = false


## Handles the gui input notification for this unit targeting controller.
func _on_gui_input(event: InputEvent) -> void:
    if not highlighted:
        return

    if event.is_action_released("accept"):
        add_unit(unit_reference)

    if event.is_action_released("back"):
        remove_unit(unit_reference)


## Adds unit for this unit targeting controller.
func add_unit(unit: BattleUnit) -> void:
    CustomLogger.hint(self, add_unit, "Adding target unit: %s" % unit, CustomLogger.LEVEL.VERY_VERBOSE)
    if use_global_selection:
        SignalBus.add_target.emit(unit)
    else:
        target_added.emit(unit)


## Removes unit for this unit targeting controller.
func remove_unit(unit: BattleUnit) -> void:
    CustomLogger.hint(self, remove_unit, "Removing target unit: %s" % unit, CustomLogger.LEVEL.VERY_VERBOSE)
    if use_global_selection:
        SignalBus.remove_target.emit(unit)
    else:
        target_removed.emit(unit)


## Shows symbol for this unit targeting controller.
func show_symbol(amount: float = 0.5) -> void:
    if not skill_selected:
        return
    var texture_rect: TextureRect = highlighted_symbol.get(skill_selected.type)
    if not texture_rect:
        return
    if not texture_rect.visible:
        texture_rect.visible = true

    var alpha_material_path = "material:shader_parameter/Alpha"
    if texture_rect.material:
        var tween = create_tween()
        tween.tween_property(texture_rect, alpha_material_path, amount, AnimationTimes.FAST)
    if texture_rect.get_child_count() < 1:
        return
    var animator: AnimationPlayer = texture_rect.get_child(0)
    animator.play("RESET")
    if amount < 0.9:
        return
    animator.play("selected")


## Hides symbols for this unit targeting controller.
func hide_symbols() -> void:
    for symbols in highlighted_symbol.values():
        symbols.visible = false
        var symbol_material: ShaderMaterial = symbols.material
        if not symbol_material:
            continue
        symbol_material.set_shader_parameter("material:shader_parameter/Alpha", 0.0)
