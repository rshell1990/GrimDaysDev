extends Control
##
##
##
## Controls the unit stats tooltip display presentation used by the battle interface.
class_name UnitStatsTooltipDisplay

##
## Fixed left align value shared by all unit stats tooltip display instances.
const LEFT_ALIGN: Vector2 = Vector2(-169.0, 134.0)
##
## Fixed right align value shared by all unit stats tooltip display instances.
const RIGHT_ALIGN: Vector2 = Vector2(285.0, 134.0)

@export_category("Labels")
##
## Configures the health label used by this unit stats tooltip display.
@export var health_label: Label
##
## Configures the mana label used by this unit stats tooltip display.
@export var mana_label: Label
##
## Configures the energy label used by this unit stats tooltip display.
@export var energy_label: Label
##
## Configures the physical resistance label used by this unit stats tooltip display.
@export var physical_resistance_label: Label
##
## Configures the speed label used by this unit stats tooltip display.
@export var speed_label: Label
##
## Configures the physical damage label used by this unit stats tooltip display.
@export var physical_damage_label: Label
##
## Configures the magical damage label used by this unit stats tooltip display.
@export var magical_damage_label: Label
##
## Configures the accuracy label used by this unit stats tooltip display.
@export var accuracy_label: Label
##
## Configures the evasion label used by this unit stats tooltip display.
@export var evasion_label: Label
##
## Configures the crit chance label used by this unit stats tooltip display.
@export var crit_chance_label: Label

@export_category("Effect Containers")
##
## Configures the buff holder used by this unit stats tooltip display.
@export var buff_holder: HBoxContainer
##
## Configures the debuff holder used by this unit stats tooltip display.
@export var debuff_holder: HBoxContainer

## Cached reference to the focus camera node, resolved when this node becomes ready.
@onready var focus_camera: PhantomCamera2D = %"Focus Camera"

##
## Whether the mouse hover condition currently holds.
var mouse_hover: bool = false
##
## Whether the started tween condition currently holds.
var started_tween: bool = false
##
## Whether the active condition currently holds.
var active: bool = true

##
## Runtime unit reference state used by this unit stats tooltip display.
var unit_reference: BattleUnit:
    get:
        return get_parent().get_parent().unit_reference


##
## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    if get_parent().get_parent().use_global_battle_navigation:
        SignalBus.battle_action_select.connect(on_battle_action_select)
        SignalBus.battle_action_selected.connect(on_battle_action_selected)


## Handles the battle action select notification for this unit stats tooltip display.
func on_battle_action_select() -> void:
    active = true
    if modulate.a > 0.0:
        _on_ui_mouse_exited()


## Handles the battle action selected notification for this unit stats tooltip display.
func on_battle_action_selected() -> void:
    active = false
    if modulate.a > 0.0:
        _on_ui_mouse_exited()


##
## Handles input events for this unit stats tooltip display.
func _input(event: InputEvent) -> void:
    if not active:
        return
    if event.is_action_released("accept"):
        on_accept()
    elif event.is_action_released("back"):
        on_back()


##
## Handles the display notification for this unit stats tooltip display.
func on_display() -> void:
    if not is_instance_valid(unit_reference):
        return
    set_resource_values()
    set_combat_stat_values()
    set_current_effects()


##
## Sets current effects for this unit stats tooltip display.
func set_current_effects() -> void:
    for child in buff_holder.get_children():
        child.queue_free()
    for child in debuff_holder.get_children():
        child.queue_free()


##
## Sets combat stat values for this unit stats tooltip display.
func set_combat_stat_values() -> void:
    set_stat_label(CombatStats.STATS.PhysicalResistance, physical_resistance_label)
    speed_label.text = str(unit_reference.speed)

    var physical_damage: UnitGenericStat = unit_reference.get_stat(CombatStats.STATS.PhysicalDamage)
    var damage_modifier_stat: UnitGenericStat = unit_reference.get_stat(CombatStats.STATS.DamageModifier)
    if not physical_damage or not damage_modifier_stat:
        physical_damage_label.text = "-"
    else:
        var damage_modifier: float = damage_modifier_stat.Current
        var physical_damage_min: int = roundi(
            (physical_damage.Current * CombatDamage.PHYSICAL_DAMAGE_MIN_MODIFIER) * damage_modifier
        )
        var physical_damage_max: int = roundi(
            (physical_damage.Current * CombatDamage.PHYSICAL_DAMAGE_MAX_MODIFIER) * damage_modifier
        )
        #print(unit_reference, ": Base Damage -", physical_damage," Damage Modifier -" ,damage_modifier)
        physical_damage_label.text = str(physical_damage_min) + " - " + str(physical_damage_max)

    #set_stat_label(CombatStats.STATS.PhysicalDamage, physical_damage_label)
    set_stat_label(CombatStats.STATS.MagicDamage, magical_damage_label)

    set_stat_label(CombatStats.STATS.Accuracy, accuracy_label)
    set_stat_label(CombatStats.STATS.Evasion, evasion_label)
    set_stat_label(CombatStats.STATS.CriticalStrike, crit_chance_label)


##
## Sets stat label for this unit stats tooltip display.
func set_stat_label(stat_type: CombatStats.STATS, label: Label) -> void:
    var stat: UnitGenericStat = unit_reference.get_stat(stat_type)
    if not stat:
        return
    label.text = str(stat.Current)


##
## Sets resource values for this unit stats tooltip display.
func set_resource_values() -> void:
    set_resource_value(health_label, CombatStats.STATS.Health)
    set_resource_value(mana_label, CombatStats.STATS.Mana)
    set_resource_value(energy_label, CombatStats.STATS.Energy)


##
## Sets resource value for this unit stats tooltip display.
func set_resource_value(resource_label: Label, resource_type: CombatStats.STATS) -> void:
    var resource: UnitGenericStat = unit_reference.get_stat(resource_type)
    if not resource:
        resource_label.get_parent().get_parent().visible = false
        return

    resource_label.text = str(roundi(resource.percentage)) + "%"


##
## Handles the ui mouse entered notification for this unit stats tooltip display.
func _on_ui_mouse_entered() -> void:
    if not active:
        return
    #print("MOUSE ENTERED UI for: ", owner)
    mouse_hover = true
    await get_tree().create_timer(AnimationTimes.STANDARD).timeout
    if not mouse_hover:
        return
    on_display()
    var tween: Tween = create_tween()
    tween.tween_property(self, "modulate:a", 1.0, AnimationTimes.FAST)


##
## Handles the tween start notification for this unit stats tooltip display.
func on_tween_start() -> void:
    started_tween = true
    if not focus_camera.tween_started.is_connected(on_tween_start):
        return
    focus_camera.tween_started.disconnect(on_tween_start)


##
## Handles the tween end notification for this unit stats tooltip display.
func on_tween_end() -> void:
    started_tween = false
    if not focus_camera.tween_completed.is_connected(on_tween_end):
        return
    focus_camera.tween_completed.disconnect(on_tween_end)
    await get_tree().create_timer(AnimationTimes.SLOW).timeout


##
## Handles the ui mouse exited notification for this unit stats tooltip display.
func _on_ui_mouse_exited() -> void:
    if started_tween:
        return
    #print("MOUSE EXITED UI for: ", owner)
    mouse_hover = false
    if modulate.a < 0.01:
        return
    await get_tree().create_timer(AnimationTimes.FAST).timeout
    if mouse_hover:
        return
    var tween: Tween = create_tween()
    tween.tween_property(self, "modulate:a", 0.0, AnimationTimes.FAST)


##
## Handles the accept notification for this unit stats tooltip display.
func on_accept() -> void:
    if not mouse_hover:
        return
    if not focus_camera.tween_started.is_connected(on_tween_start):
        focus_camera.tween_started.connect(on_tween_start)
    if not focus_camera.tween_completed.is_connected(on_tween_end):
        focus_camera.tween_completed.connect(on_tween_end)
    focus_camera.priority = 25
    get_parent().z_index = 1


##
## Handles the back notification for this unit stats tooltip display.
func on_back() -> void:
    _on_ui_mouse_exited()
    if focus_camera.priority < 1:
        return
    focus_camera.priority = 0
    get_parent().z_index = 0
