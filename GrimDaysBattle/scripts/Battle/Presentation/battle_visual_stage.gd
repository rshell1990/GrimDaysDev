extends Node2D
## Creates and manages on-screen displays for the battle's units. Other scripts choose units and run
## turns.
class_name BattleVisualStage

## Notification for target added. Supplies [code]session_id[/code], [code]unit[/code] to connected
## functions.
signal target_added(session_id: int, unit: BattleUnit)
## Notification for target removed. Supplies [code]session_id[/code], [code]unit[/code] to connected
## functions.
signal target_removed(session_id: int, unit: BattleUnit)

## Parent node and display scene used to show the player's allies.
@export var ally_holder: Unit2DParty
## Parent node and display scene used to show opponents.
@export var foe_holder: Unit2DParty
## Shape that defines how far each unit's camera is allowed to move.
@export var camera_bounds: CollisionShape2D
## Optional background sprite used by story-authored stage textures.
@export var background: Sprite2D

## Reason the most recent display setup failed; cleared when setup starts again.
var last_error: String = ""
## Battle manager supplying the units shown here and announcing when their battle ends.
var _coordinator: BattleCoordinator
## Battle attempt number used to ignore notifications from earlier attempts.
var _session_id: int = -1
## Dictionary used to find the on-screen display for each battle unit.
var _displays: Dictionary[BattleUnit, Unit2DDisplay] = {}
## Player-controlled unit whose action is currently waiting for target selection.
var _selected_actor: BattleUnit
## Chosen action, whose rules decide which units the player can select as targets.
var _selected_action: ActionTemplate
## One binding's cosmetic service; invalidated before any display is released.
var _effect_presentation: BattleEffectPresentation


## Null preserves the scene default. Unit cleanup and retries leave this texture intact.
func set_background_texture(texture: Texture2D) -> void:
    if texture and is_instance_valid(background):
        background.texture = texture


## Sets up displays for the battle manager's existing units. Returns false if setup cannot complete.
func bind_encounter(coordinator: BattleCoordinator) -> bool:
    last_error = ""
    if not is_inside_tree() or not is_instance_valid(coordinator):
        return _reject("A live stage and coordinator are required.")
    if not coordinator.is_current_session(coordinator.session_id):
        return _reject("Visual deployment requires an active encounter.")
    if not is_instance_valid(ally_holder) or not is_instance_valid(foe_holder) or not is_instance_valid(camera_bounds):
        return _reject("Visual deployment requires both display holders and camera bounds.")
    if not ally_holder.is_inside_tree() or not foe_holder.is_inside_tree() or not camera_bounds.is_inside_tree():
        return _reject("Visual dependencies must be in the scene tree.")
    if not ally_holder.unit_display_template or not foe_holder.unit_display_template:
        return _reject("Both visual holders require a display scene.")
    for unit in coordinator.roster.get_participants():
        if not is_instance_valid(unit) or not unit.template_resource or not unit.get_battle_sprite():
            return _reject("Every participant requires a runtime unit and battle sprite.")
    clear()
    _coordinator = coordinator
    _session_id = coordinator.session_id
    _effect_presentation = BattleEffectPresentation.new(self, _session_id)
    _coordinator.battle_clearing.connect(_on_battle_clearing)
    _coordinator.battle_finished.connect(_on_battle_finished)
    if not _deploy_side(coordinator.roster.get_allies(), ally_holder, true):
        clear()
        return false
    if not _deploy_side(coordinator.roster.get_foes(), foe_holder, false):
        clear()
        return false
    return true


## Returns the on-screen display for the supplied unit object, or null if it has no display.
func get_unit_display(unit: BattleUnit) -> Unit2DDisplay:
    return _displays.get(unit)


## Shows target choices for the supplied unit and action.
## Returns false unless this is the current attempt and the unit can take that player-controlled
## action.
func select_targets(token: int, actor: BattleUnit, action: ActionTemplate) -> bool:
    if not _is_current(token) or not is_instance_valid(actor) or not action:
        return false
    if actor != _coordinator.turn_order.get_active_unit() or not actor.player_controlled:
        return false
    if not actor.can_use_action(action):
        return false
    _selected_actor = actor
    _selected_action = action
    for display in _displays.values():
        display.show_target_selection(actor, action)
        display.stats_tooltip_panel.on_battle_action_selected()
    return true


## Stops target selection and restores tooltips only if the supplied attempt number matches this
## display's battle.
func clear_target_selection(token: int) -> void:
    if token != _session_id:
        return
    _selected_actor = null
    _selected_action = null
    for display in _displays.values():
        if is_instance_valid(display):
            display.on_target_set()
            display.stats_tooltip_panel.on_battle_action_select()


## Removes this battle's unit displays and their notification connections. Keeps the units
## themselves and scene decorations.
func clear() -> void:
    clear_target_selection(_session_id)
    if _effect_presentation:
        _effect_presentation.close()
        _effect_presentation = null
    if is_instance_valid(_coordinator):
        if _coordinator.battle_clearing.is_connected(_on_battle_clearing):
            _coordinator.battle_clearing.disconnect(_on_battle_clearing)
        if _coordinator.battle_finished.is_connected(_on_battle_finished):
            _coordinator.battle_finished.disconnect(_on_battle_finished)
    for display in _displays.values():
        if not is_instance_valid(display):
            continue
        display.targeting_controller.target_added.disconnect(_on_target_added)
        display.targeting_controller.target_removed.disconnect(_on_target_removed)
        # Disconnect resource bindings immediately, before deferred destruction.
        display.unit_reference = null
        display.stats_display.initialize(null)
        display.display_lookup = Callable()
        display.active_unit_provider = Callable()
        display.hide()
        display.queue_free()
    _displays.clear()
    _coordinator = null
    _session_id = -1


## Creates a display for each unit and places it in the formation. Returns false if the display
## scene creates the wrong kind of node.
func _deploy_side(units: Array[BattleUnit], holder: Unit2DParty, allied: bool) -> bool:
    for index in units.size():
        var candidate := holder.unit_display_template.instantiate()
        if candidate is not Unit2DDisplay:
            candidate.free()
            return _reject("The visual holder's scene must instantiate Unit2DDisplay.")
        var display: Unit2DDisplay = candidate
        display.use_global_battle_navigation = false
        display.display_lookup = get_unit_display
        display.active_unit_provider = _get_active_unit
        display.initialize(units[index].template_resource, camera_bounds)
        holder.add_child(display)
        display.position = _formation_position(index, units.size(), allied)
        display.original_position = display.global_position
        display.unit_reference = units[index]
        display.stats_display.initialize(units[index])
        # Front-row Spine sprites must not cover a back-row unit's name/Health.
        display.stats_display.z_index = 10
        display.stats_tooltip_panel.position = (
            UnitStatsTooltipDisplay.LEFT_ALIGN if allied else UnitStatsTooltipDisplay.RIGHT_ALIGN
        )
        display.on_target_set()
        display.targeting_controller.target_added.connect(_on_target_added)
        display.targeting_controller.target_removed.connect(_on_target_removed)
        _displays[units[index]] = display
        _effect_presentation.bind_unit(units[index])
    return true


## Two rows, with columns centered on the holder. The 360px spacing leaves room
## for the authored roughly 330px name/Health bars without pushing the outer column off
## the 1920px courtyard. This formation belongs only to the production stage.
func _formation_position(index: int, count: int, allied: bool) -> Vector2:
    if count == 1:
        return Vector2.ZERO
    var row: int = index % 2
    var column: int = floori(float(index) / 2.0)
    var columns: int = ceili(float(count) / 2.0)
    var horizontal: float = (float(column) - float(columns - 1) / 2.0) * 360.0
    return Vector2(-horizontal if allied else horizontal, -100.0 if row == 0 else 100.0)


## Returns the next unit to act in this display's battle, or null if that attempt has ended.
func _get_active_unit() -> BattleUnit:
    return _coordinator.turn_order.get_active_unit() if _is_current(_session_id) else null


## Checks that the supplied attempt number matches the battle currently running on this display.
func _is_current(token: int) -> bool:
    return token == _session_id and is_instance_valid(_coordinator) and _coordinator.is_current_session(token)


## Returns whether the selected unit is shown here and is an allowed target for the current
## player-controlled turn.
func _valid_selection(unit: BattleUnit) -> bool:
    return (
        _is_current(_session_id)
        and _displays.has(unit)
        and is_instance_valid(_selected_actor)
        and _selected_actor == _get_active_unit()
        and _selected_actor.player_controlled
        and _selected_action != null
        and CombatActions.valid_target(_selected_action, _selected_actor, unit)
    )


## Announces an allowed target selection together with the battle attempt number.
func _on_target_added(unit: BattleUnit) -> void:
    if _valid_selection(unit):
        target_added.emit(_session_id, unit)


## Announces an allowed target deselection together with the battle attempt number.
func _on_target_removed(unit: BattleUnit) -> void:
    if _valid_selection(unit):
        target_removed.emit(_session_id, unit)


## Removes unit displays when their battle begins cleanup.
func _on_battle_clearing(token: int) -> void:
    if token == _session_id:
        clear()


## Closes target selection for the finished encounter while leaving displays visible.
func _on_battle_finished(token: int, _result: BattleResult) -> void:
    clear_target_selection(token)


## Stops listening for battle notifications and removes unit displays when this node leaves the
## scene.
func _exit_tree() -> void:
    clear()


## Stores the reason display setup failed and returns false.
func _reject(message: String) -> bool:
    last_error = message
    return false
