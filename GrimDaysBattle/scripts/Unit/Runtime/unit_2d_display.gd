# Editor configuration for Unit2DDisplay.
@icon("res://GrimDays/assets/visuals/class_icons/swordman.svg")
extends Node2D
## Coordinates 2D unit display behavior for the battle system.
class_name Unit2DDisplay

#region CONSTANTS
## Minimum randomized startup phase of the idle animation, in seconds.
const MIN_DELAY: float = 0.0
## Maximum randomized startup phase of the idle animation, in seconds.
const MAX_DELAY: float = 0.85
## Fixed move to percentage value shared by all 2D unit display instances.
const MOVE_TO_PERCENTAGE: float = 0.35
## Fixed idle animation value shared by all 2D unit display instances.
const IDLE_ANIMATION: StringName = &"idle"
## Fixed ally move towards animation value shared by all 2D unit display instances.
const ALLY_MOVE_TOWARDS_ANIMATION: StringName = &"move_right"
#endregion

#region SIGNALS
## Emitted to notify listeners that colliding occurred.
signal colliding(myself, other)
## Emitted to notify listeners that rays colliding occurred.
signal rays_colliding(myself, rays)
## Local navigation completion for production; debug uses the legacy signal bus.
signal movement_finished(active: BattleUnit, target: BattleUnit, request_id: StringName)
#endregion

#region ONREADY / EXPORT
## Cached reference to the targeting controller node, resolved when this node becomes ready.
@onready var targeting_controller: UnitTargetingController = $"UI Elements/Targeting Controller"
## Cached reference to the mouse trigger node, resolved when this node becomes ready.
@onready var mouse_trigger: Control = $"UI Elements/Mouse Trigger"
## Configures the ui zone used by this 2D unit display.
@export var ui_zone: Control
## Configures the sprite holder used by this 2D unit display.
@export var sprite_holder: Node2D
## Configures the targeting ui used by this 2D unit display.
@export var targeting_ui: Control
## Configures the stats tooltip panel used by this 2D unit display.
@export var stats_tooltip_panel: Control
## Configures the stats display used by this 2D unit display.
@export var stats_display: Control
## Configures the health bar used by this 2D unit display.
@export var health_bar: TextureProgressBar

## Cached reference to the combat camera node, resolved when this node becomes ready.
@onready var combat_camera: PhantomCamera2D = %"Combat Camera"
## Cached reference to the focus camera node, resolved when this node becomes ready.
@onready var focus_camera: PhantomCamera2D = %"Focus Camera"
#endregion

#region VARS / PROPERTIES
## Runtime original position state used by this 2D unit display.
var original_position: Vector2
## Runtime appearance scene state used by this 2D unit display.
var appearance_scene: Unit2DSprite
## Runtime appearance template scene state used by this 2D unit display.
var appearance_template_scene: PackedScene
## Whether the repositioned condition currently holds.
var repositioned: bool = false
## Ordered runtime collection of camera limits.
var camera_limits: CollisionShape2D
## Runtime skill selected state used by this 2D unit display.
var skill_selected: ActionTemplate
## Runtime health resource state used by this 2D unit display.
var health_resource: UnitGenericStat
## Runtime health tween state used by this 2D unit display.
var health_tween: Tween
## Runtime unit reference state used by this 2D unit display.
var _unit_reference: BattleUnit
## Production scenes inject lookups and route selection locally. The default
## retains the existing debug scene's global-signal contract.
var use_global_battle_navigation: bool = true
## Function supplied by the battle display: takes a BattleUnit and returns its on-screen display.
var display_lookup: Callable
## Function supplied by the battle display: takes no arguments and returns the unit taking a turn
## when game-wide navigation is disabled.
var active_unit_provider: Callable
## The spine appearance of this unit if it has one.
var spine_appearance: SpineSpriteOverride
## Runtime unit reference state used by this 2D unit display.
var unit_reference: BattleUnit:
    get:
        return _unit_reference
    set(value):
        _set_unit_reference(value)
#endregion


#region SIGNAL RESPONSES
##
## Handles the health change notification for this 2D unit display.
func on_health_change(stat: UnitGenericStat, _old_value: float, new_value: float) -> void:
    if stat != health_resource:
        return
    health_bar.min_value = stat.Min
    health_bar.max_value = stat.Max
    _stop_health_tween()
    health_tween = create_tween()
    health_tween.tween_property(health_bar, "value", new_value, AnimationTimes.STANDARD)
    CustomLogger.hint(self, on_health_change, "Health changed to %s." % new_value, CustomLogger.LEVEL.VERY_VERBOSE)


## Sets unit reference for this 2D unit display.
func _set_unit_reference(value: BattleUnit) -> void:
    CustomLogger.hint(
        self, _set_unit_reference, "Setting unit reference to %s." % value, CustomLogger.LEVEL.VERY_VERBOSE
    )
    _disconnect_health_resource()
    _disconnect_battle_sprite()
    _stop_health_tween()
    _unit_reference = value
    if _unit_reference:
        _unit_reference.battle_sprite_changed.connect(on_battle_sprite_changed)
        var effective_sprite: PackedScene = _unit_reference.get_battle_sprite()
        if effective_sprite and effective_sprite != appearance_template_scene:
            _replace_appearance_scene(effective_sprite)
    health_resource = _unit_reference.get_stat(CombatStats.STATS.Health) if _unit_reference else null
    # The authored display shares its health control with UnitStatusBar. Only
    # that component may update it; otherwise raw values and ratios fight.
    if stats_display is UnitStatusBar and stats_display.health_bar == health_bar:
        stats_display.initialize(_unit_reference)
        return
    if not health_resource:
        health_bar.visible = false
        return
    health_bar.visible = true
    health_bar.min_value = health_resource.Min
    health_bar.max_value = health_resource.Max
    health_bar.value = health_resource.Current
    health_resource.value_changed.connect(on_health_change)


## Disconnects health resource for this 2D unit display.
func _disconnect_health_resource() -> void:
    if health_resource and health_resource.value_changed.is_connected(on_health_change):
        health_resource.value_changed.disconnect(on_health_change)
    health_resource = null


## Disconnects battle sprite for this 2D unit display.
func _disconnect_battle_sprite() -> void:
    if _unit_reference and _unit_reference.battle_sprite_changed.is_connected(on_battle_sprite_changed):
        _unit_reference.battle_sprite_changed.disconnect(on_battle_sprite_changed)


## Handles the battle sprite changed notification for this 2D unit display.
func on_battle_sprite_changed(sprite_scene: PackedScene) -> void:
    _replace_appearance_scene(sprite_scene)


## Handles appearance scene for this 2D unit display.
func _replace_appearance_scene(sprite_scene: PackedScene) -> void:
    if not sprite_scene or sprite_scene == appearance_template_scene:
        return
    var candidate: Node = sprite_scene.instantiate()
    if candidate is not Unit2DSprite:
        (
            CustomLogger
            . error(
                self,
                _replace_appearance_scene,
                "Battle sprite scene must instantiate Unit2DSprite.",
                CustomLogger.LEVEL.IMPORTANT,
            )
        )
        candidate.free()
        return
    var new_appearance: Unit2DSprite = candidate
    if new_appearance.collision_area:
        new_appearance.collision_area.area_entered.connect(on_area_collision)
    if new_appearance.raycaster and new_appearance.raycaster.has_signal("colliding"):
        new_appearance.raycaster.colliding.connect(on_ray_collision)
    if appearance_scene:
        appearance_scene.queue_free()
    appearance_scene = new_appearance
    appearance_template_scene = sprite_scene
    sprite_holder.add_child(appearance_scene)
    check_for_spine_sprite()


## Stops health tween for this 2D unit display.
func _stop_health_tween() -> void:
    if health_tween and health_tween.is_valid():
        health_tween.kill()
    health_tween = null


## Handles the critical damage notification for this 2D unit display.
func on_critical_damage(unit) -> void:
    if unit != unit_reference:
        return
    CustomLogger.hint(
        self, on_critical_damage, "Critical damage presentation triggered.", CustomLogger.LEVEL.VERY_VERBOSE
    )
    %"Critical Hit".stop()
    %"Critical Hit".play()


## Handles the critical hit notification for this 2D unit display.
func on_critical_hit(unit) -> void:
    if unit != unit_reference:
        return
    CustomLogger.hint(self, on_critical_hit, "Critical-hit presentation triggered.", CustomLogger.LEVEL.VERY_VERBOSE)
    %"Critical Attack".stop()
    %"Critical Attack".play()


## Handles the lucky notification for this 2D unit display.
func on_lucky(unit) -> void:
    if unit != unit_reference:
        return
    CustomLogger.hint(self, on_lucky, "Lucky presentation triggered.", CustomLogger.LEVEL.VERY_VERBOSE)
    %"Lucky".play()


## Handles the pity notification for this 2D unit display.
func on_pity(unit) -> void:
    if unit != unit_reference:
        return
    CustomLogger.hint(self, on_pity, "Pity presentation triggered.", CustomLogger.LEVEL.VERY_VERBOSE)
    %"Pity".play()


##
## Handles the area collision notification for this 2D unit display.
func on_area_collision(other_area: Area2D) -> void:
    colliding.emit(self, other_area)


##
## Handles the ray collision notification for this 2D unit display.
func on_ray_collision(rays: Array[RayCast2D]) -> void:
    rays_colliding.emit(self, rays)


##
## Handles the play battle animation notification for this 2D unit display.
func on_play_battle_animation(target: Variant, animation_id: StringName, request_id: StringName) -> void:
    if target != unit_reference:
        return
    var animator: AnimationPlayer = %Animator
    if not animator.has_animation(animation_id):
        SignalBus.played_battle_animation.emit(target, animation_id, request_id)
        return
    animator.play(animation_id)
    var completed_animation: StringName = await animator.animation_finished
    if completed_animation == animation_id:
        SignalBus.played_battle_animation.emit(target, animation_id, request_id)


## Starts an authored Spine clip and returns one cycle's duration, or -1 when unavailable.
## Playback completion/default-pose restoration belongs to SpineSpriteOverride.
func play_spine_animation(animation_name: StringName, loop: bool = false, track_number: int = 0) -> float:
    if not is_instance_valid(spine_appearance) or animation_name.is_empty() or track_number < 0:
        return -1.0
    if not spine_appearance.check_for_animation(animation_name):
        return -1.0
    var seconds := spine_appearance.get_animation_length(animation_name)
    if not is_finite(seconds) or seconds < 0.0:
        return -1.0
    spine_appearance.play_animation(animation_name, loop, track_number)
    return seconds


## Handles the spawn battle particles notification for this 2D unit display.
func on_spawn_battle_particles(
    target: Variant,
    particle_scene: PackedScene,
    lifetime_seconds: float,
    request_id: StringName,
    animation_name: StringName = &"",
    starting_offset: Vector2 = Vector2.ZERO
) -> void:
    if target != unit_reference:
        return
    if not particle_scene:
        SignalBus.spawned_battle_particles.emit(target, request_id)
        return
    var particles := particle_scene.instantiate()
    var particle_holder := get_node_or_null("Generic Particles")
    (particle_holder if particle_holder else self).add_child(particles)
    if animation_name.is_empty() and starting_offset != Vector2.ZERO:
        if particles is Node2D or particles is Control:
            particles.position += starting_offset
    if particles is GPUParticles2D or particles is CPUParticles2D:
        particles.emitting = true
    if not animation_name.is_empty():
        var animator := particles.get_node_or_null("%Animator") as AnimationPlayer
        if animator and animator.has_animation(animation_name):
            animator.animation_finished.connect(_on_particle_animation_finished.bind(animation_name, particles))
            animator.play(animation_name)
        else:
            CustomLogger.warn(
                self,
                on_spawn_battle_particles,
                "Particle scene requires %%Animator with animation %s." % animation_name,
                CustomLogger.LEVEL.IMPORTANT
            )
            if lifetime_seconds > 0.0:
                get_tree().create_timer(lifetime_seconds).timeout.connect(particles.queue_free, CONNECT_ONE_SHOT)
    elif particles is AnimatedSprite2D:
        particles.play()
        particles.animation_finished.connect(particles.queue_free, CONNECT_ONE_SHOT)
    elif (particles is GPUParticles2D or particles is CPUParticles2D) and particles.one_shot:
        particles.finished.connect(particles.queue_free, CONNECT_ONE_SHOT)
    elif lifetime_seconds > 0.0:
        get_tree().create_timer(lifetime_seconds).timeout.connect(particles.queue_free, CONNECT_ONE_SHOT)
    SignalBus.spawned_battle_particles.emit(target, request_id)


## Ignore unrelated clips; only the requested particle animation owns this cleanup.
func _on_particle_animation_finished(completed: StringName, expected: StringName, particles: Node) -> void:
    if completed == expected and is_instance_valid(particles):
        particles.queue_free()


## Handles the play battle sound notification for this 2D unit display.
func on_play_battle_sound(
    target: Variant, sound: AudioStream, volume_db: float, pitch_scale: float, request_id: StringName
) -> void:
    if target != unit_reference:
        return
    if not sound:
        SignalBus.played_battle_sound.emit(target, request_id)
        return
    var player := AudioStreamPlayer.new()
    player.stream = sound
    player.volume_db = volume_db
    player.pitch_scale = pitch_scale
    add_child(player)
    player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)
    player.play()
    SignalBus.played_battle_sound.emit(target, request_id)


##
## Handles the switch to combat camera notification for this 2D unit display.
func on_switch_to_combat_camera(unit: BattleUnit) -> void:
    if unit != unit_reference:
        return
    combat_camera.priority = 50


##
## Handles the switch away from combat camera notification for this 2D unit display.
func on_switch_away_from_combat_camera() -> void:
    if combat_camera.priority < 1:
        return
    combat_camera.priority = 0


##
## Handles the move towards unit notification for this 2D unit display.
func on_move_towards_unit(active: BattleUnit, target: BattleUnit, request_id: StringName) -> void:
    CustomLogger.hint(
        self, on_move_towards_unit, "Moving %s towards %s." % [active, target], CustomLogger.LEVEL.IMPORTANT
    )
    if active != unit_reference and target != unit_reference:
        var modulate_tween: Tween = create_tween()
        await (
            modulate_tween
            . tween_property(self, "modulate", Color.from_string("#454545ff", Color.BLACK), AnimationTimes.FAST)
            . finished
        )
    if active != unit_reference:
        return
    z_index = 25
    original_position = global_position
    var target_display: Unit2DDisplay = (
        BattleController.get_unit_display(target)
        if use_global_battle_navigation
        else display_lookup.call(target) if display_lookup.is_valid() else null
    )
    if not target_display:
        _emit_movement_finished(target, request_id)
        return
    var lerp_point_x = lerp(original_position.x, target_display.global_position.x, MOVE_TO_PERCENTAGE)
    var lerp_point_y = lerp(original_position.y, target_display.global_position.y, MOVE_TO_PERCENTAGE * 2)
    if not spine_appearance and get_parent().name == "Allies":
        %"Animator".play(ALLY_MOVE_TOWARDS_ANIMATION)
    var tween: Tween = create_tween()
    tween.tween_property(self, "global_position", Vector2(lerp_point_x, lerp_point_y), AnimationTimes.FAST)
    await tween.finished
    if not spine_appearance:
        %Animator.play(IDLE_ANIMATION)
    _emit_movement_finished(target, request_id)


## Announces that movement finished, including the request ID so the waiting action can recognize
## it.
## Sends the notification either game-wide or from this display, depending on its settings.
func _emit_movement_finished(target: BattleUnit, request_id: StringName) -> void:
    if use_global_battle_navigation:
        SignalBus.unit_moved_towards_unit.emit(unit_reference, target, request_id)
    else:
        movement_finished.emit(unit_reference, target, request_id)


##
## Restores to original position for this 2D unit display.
func return_to_original_position(active: BattleUnit) -> void:
    var modulate_tween: Tween = create_tween()
    await modulate_tween.tween_property(self, "modulate", Color.WHITE, AnimationTimes.FAST).finished
    if active != unit_reference:
        return
    var tween: Tween = create_tween()
    tween.tween_property(self, "global_position", original_position, AnimationTimes.FAST)
    z_index = 0


## Handles the action selected notification for this 2D unit display.
func on_action_selected(action: ActionTemplate) -> void:
    var active_unit: BattleUnit = (
        BattleController.get_active_unit()
        if use_global_battle_navigation
        else active_unit_provider.call() if active_unit_provider.is_valid() else null
    )
    show_target_selection(active_unit, action)


## Production targeting receives its actor explicitly, never from a singleton.
func show_target_selection(active_unit: BattleUnit, action: ActionTemplate) -> void:
    on_target_set()
    if not action or not active_unit:
        return
    (
        CustomLogger
        . hint(
            self,
            on_action_selected,
            "%s targets category %s." % [action.display_name, action.target],
            CustomLogger.LEVEL.VERY_VERBOSE,
        )
    )
    if not action.target in [CombatActions.TARGET.ALLY, CombatActions.TARGET.FOE]:
        return

    var validate_target: Callable = CombatActions.valid_target
    if validate_target.call(action, active_unit, unit_reference):
        targeting_controller.skill_selected = action
        targeting_controller.show_symbol()
        mouse_trigger.mouse_filter = Control.MOUSE_FILTER_STOP
        mouse_trigger.visible = true
    else:
        targeting_controller.hide_symbols()
        mouse_trigger.mouse_filter = Control.MOUSE_FILTER_IGNORE
        mouse_trigger.visible = false


## Handles the target set notification for this 2D unit display.
func on_target_set() -> void:
    targeting_controller.hide_symbols()
    targeting_controller.skill_selected = null
    targeting_controller.highlighted = false
    mouse_trigger.mouse_filter = Control.MOUSE_FILTER_IGNORE
    mouse_trigger.visible = false


#endregion


#region INFORMATION
##
## Returns raycaster for this 2D unit display.
func get_raycaster() -> Variant:
    if not appearance_scene:
        return null
    return appearance_scene.raycaster


##
## Handles colliding count for this 2D unit display.
func rays_colliding_count() -> int:
    var raycaster = get_raycaster()
    if not raycaster:
        return 0
    return raycaster.rays_colliding.size()


#endregion


#region HOUSEKEEPING
##
## Initializes initialize for this 2D unit display.
func initialize(template: BattleUnitTemplate, bounds: CollisionShape2D) -> void:
    camera_limits = bounds
    name = template.id
    _replace_appearance_scene(template.battle_sprite)


## Releases owned state and signal-driven effects before this node leaves the scene tree.
func _exit_tree() -> void:
    _disconnect_health_resource()
    _disconnect_battle_sprite()
    _stop_health_tween()


##
## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    check_for_spine_sprite()
    play_idle_if_needed()
    if use_global_battle_navigation:
        SignalBus.switch_to_combat_camera.connect(on_switch_to_combat_camera)
        SignalBus.unit_moved_towards_unit.connect(on_move_towards_unit)
        SignalBus.unit_move_to_original_position.connect(return_to_original_position)
        SignalBus.switch_away_from_combat_camera.connect(on_switch_away_from_combat_camera)
        SignalBus.action_selected.connect(on_action_selected)
        SignalBus.target_set.connect(on_target_set)
        # Production views receive these requests through their local dispatcher.
        SignalBus.play_battle_animation.connect(on_play_battle_animation)
        SignalBus.spawn_battle_particles.connect(on_spawn_battle_particles)
        SignalBus.play_battle_sound.connect(on_play_battle_sound)
    focus_camera.set_limit_target(camera_limits.get_path())
    combat_camera.set_limit_target(camera_limits.get_path())
    if get_parent().name == "Foes":
        combat_camera.follow_offset = Vector2(combat_camera.follow_offset.x * -1.0, combat_camera.follow_offset.y)
    if use_global_battle_navigation:
        SignalBus.received_crit.connect(on_critical_damage)
        SignalBus.preformed_crit.connect(on_critical_hit)
    SignalBus.luck_triggered.connect(on_lucky)
    SignalBus.pity_triggered.connect(on_pity)
    #


#endregion


func check_for_spine_sprite() -> void:
    spine_appearance = null
    if not sprite_holder:
        return
    var appearance_sprite: Node = appearance_scene
    if not is_instance_valid(appearance_sprite) and sprite_holder.get_child_count() > 0:
        appearance_sprite = sprite_holder.get_child(0)
    if not appearance_sprite:
        CustomLogger.warn(
            self, play_idle_if_needed, "No appearance sprite found for: " + self.name, CustomLogger.LEVEL.VERBOSE
        )
        return
    for appearance_sprite_child in appearance_sprite.get_children():
        if appearance_sprite_child is SpineSpriteOverride:
            spine_appearance = appearance_sprite_child
            break


## Idle should be skipped if this unit is meant to use a spine sprite, so
func play_idle_if_needed() -> void:
    if spine_appearance:
        return

    # Stagger the idle phase synchronously. A delayed play could replace an attack
    # or retained death pose after production presentation has taken ownership.
    %Animator.play(IDLE_ANIMATION)
    %Animator.advance(randf_range(MIN_DELAY, MAX_DELAY))
