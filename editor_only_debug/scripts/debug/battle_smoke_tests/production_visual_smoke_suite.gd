extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"

## Resource loaded for stage; reused instead of looking up the file on each call.
const STAGE := preload("res://GrimDaysBattle/scenes/battle/production_visual_stage.tscn")
## Script loaded for coordinator; reused instead of looking up the file on each call.
const COORDINATOR := preload("res://GrimDaysBattle/scripts/Battle/Runtime/battle_coordinator.gd")


class IsolatedParty:
    extends BattlePartyManager

    func _ready() -> void:
        pass


## Records the Spine API contract without requiring animation-completed signals.
class SpineProbe:
    extends SpineSpriteOverride
    var calls: Array[Dictionary] = []
    var seconds: float = 0.2

    func check_for_animation(animation_name: String) -> bool:
        return animation_name == "probe_"

    func get_animation_length(animation_name: String) -> float:
        return seconds if check_for_animation(animation_name) else 0.0

    func play_animation(animation_name: String, loop: bool = false, track_number: int = 0) -> void:
        calls.append({"name": animation_name, "loop": loop, "track": track_number})


## Runs the production visual smoke checks. Creates or uses test objects and stops on failed
## assertions.
func run() -> void:
    var party := IsolatedParty.new()
    add_child(party)
    var ally := BattleUnit.create(CELINE_TEMPLATE)
    party.add_child(ally)
    party.runtime_units[CELINE_TEMPLATE.id] = ally
    party.active_party_ids = [CELINE_TEMPLATE.id]
    var prior_dispatch := func(_kind: StringName, _payload: Dictionary): return false
    ally.presentation_request = prior_dispatch
    var health := ally.get_stat(CombatStats.STATS.Health)
    health.decrease_current_flat(5.0)
    var coordinator := COORDINATOR.new()
    add_child(coordinator)
    var stage: BattleVisualStage = STAGE.instantiate()
    add_child(stage)
    assert(not stage.bind_encounter(coordinator), "Cannot bind before deployment.")
    assert(coordinator.begin_encounter(party, [CELINE_TEMPLATE], &"visual_binding", 99))
    assert(stage.bind_encounter(coordinator), stage.last_error)
    var token: int = coordinator.session_id
    var foe: BattleUnit = coordinator.roster.get_foes()[0]
    var display := stage.get_unit_display(ally)
    var foe_display := stage.get_unit_display(foe)
    assert(display and foe_display and display != foe_display)
    assert(display.unit_reference == ally and display.stats_display.unit_reference == ally)
    assert(ally.get_parent() == party, "Visual binding must not recreate or reparent allies.")
    assert(absf(display.health_bar.value - health.ratio) <= 0.001)
    assert(
        not health.value_changed.is_connected(display.on_health_change),
        "A shared health bar must have only one updater."
    )
    assert(not display.use_global_battle_navigation)
    assert(not display.targeting_controller.use_global_selection)
    assert(not SignalBus.action_selected.is_connected(display.on_action_selected))
    assert(not SignalBus.unit_moved_towards_unit.is_connected(display.on_move_towards_unit))
    assert(not SignalBus.play_battle_animation.is_connected(display.on_play_battle_animation))
    assert(not SignalBus.play_battle_sound.is_connected(display.on_play_battle_sound))
    assert(not SignalBus.spawn_battle_particles.is_connected(display.on_spawn_battle_particles))
    await _test_spine_animation_skip(stage, ally, foe)
    await _test_spine_playback(stage, ally, foe)
    # These existing checks exercise the AnimationPlayer presentation path explicitly.
    display.spine_appearance = null
    foe_display.spine_appearance = null
    await _test_startup_pose(stage, ally, foe)
    await _test_effect_dispatch(stage, ally, foe)
    await _test_particle_animations(stage.get_unit_display(ally), ally)
    await _test_event_playback(stage, ally, foe)
    assert(display.display_lookup.call(foe) == foe_display)
    health.decrease_current_flat(3.0)
    await get_tree().create_timer(AnimationTimes.STANDARD + 0.1).timeout
    assert(absf(display.health_bar.value - health.ratio) <= 0.001)
    assert(is_equal_approx(display.health_bar.max_value, 1.0))
    display.stats_tooltip_panel.on_display()
    assert(display.stats_tooltip_panel.health_label.text == str(roundi(health.percentage)) + "%")
    await _test_target_selection(coordinator, stage, ally, foe)
    # Rebind in the same frame: old displays may still exist but are disconnected.
    var old_health: UnitGenericStat = display.health_resource
    var old_dispatch: Callable = ally.presentation_request
    var old_service := stage._effect_presentation
    assert(stage.bind_encounter(coordinator))
    assert(old_dispatch.get_object() == old_service)
    assert(
        not old_dispatch.call(&"animation", {"animation_id": &"idle"}),
        "A retained callback must reject same-session display rebindings."
    )
    assert(display.unit_reference == null and display.is_queued_for_deletion())
    assert(not old_health.value_changed.is_connected(display.on_health_change))
    assert(not old_health.value_changed.is_connected(display.stats_display.on_health_resource_change))
    assert(stage.get_unit_display(ally) != display)
    assert(not display.targeting_controller.target_added.is_connected(stage._on_target_added))
    assert(not display.targeting_controller.target_removed.is_connected(stage._on_target_removed))
    await get_tree().process_frame
    assert(stage.ally_holder.get_child_count() == 1 and stage.foe_holder.get_child_count() == 1)
    display = stage.get_unit_display(ally)
    foe_display = stage.get_unit_display(foe)
    await _test_immediate_outcomes(stage, ally, foe)
    var decoration := Node2D.new()
    stage.ally_holder.add_child(decoration)
    assert(coordinator.finish(token, BattleResult.OUTCOME.VICTORY))
    assert(not ally.presentation_request.call(&"animation", {"animation_id": &"idle"}))
    assert(not stage.select_targets(token, ally, BASIC_ATTACK))
    assert(coordinator.cleanup(token))
    assert(stage.get_unit_display(ally) == null)
    assert(display.unit_reference == null and foe_display.unit_reference == null)
    assert(ally.presentation_request == prior_dispatch and foe.presentation_request.is_null())
    assert(ally.get_parent() == party)
    await get_tree().process_frame
    assert(is_instance_valid(decoration), "Clear must not remove unrelated holder children.")
    assert(stage.ally_holder.get_child_count() == 1 and stage.foe_holder.get_child_count() == 0)
    assert(coordinator.begin_encounter(party, [CELINE_TEMPLATE], &"visual_reentry", 99))
    assert(stage.bind_encounter(coordinator))
    assert(not stage.select_targets(token, ally, BASIC_ATTACK), "Old session input must be rejected.")
    var replacement_dispatch := func(_kind: StringName, _payload: Dictionary): return true
    ally.presentation_request = replacement_dispatch
    # Destroying presentation alone must leave domain ownership and state intact.
    await free_node(stage)
    assert(ally.presentation_request == replacement_dispatch, "Cleanup must not overwrite a newer callback owner.")
    assert(ally.get_parent() == party and coordinator.is_current_session(coordinator.session_id))
    assert(coordinator.cleanup(coordinator.session_id))
    await free_node(coordinator)
    await free_node(party)


## A terminal cue immediately after binding must survive the former delayed idle startup.
func _test_startup_pose(stage: BattleVisualStage, ally: BattleUnit, foe: BattleUnit) -> void:
    var player := BattleCombatPresentation.new()
    player.cue_seconds = 0.0
    add_child(player)
    var request := BattleActionRequest.new(&"startup_pose", ally, BASIC_ATTACK, [foe])
    var display := stage.get_unit_display(foe)
    var animator: AnimationPlayer = display.get_node("%Animator")
    await player.play_events(
        stage, [BattleCombatEvent.new(BattleCombatEvent.TYPE.DEFEAT, request, foe)], func(): return true
    )
    assert(display.get_node("UI Elements/Status").modulate.a == 0)
    await get_tree().create_timer(Unit2DDisplay.MAX_DELAY + 0.1).timeout
    assert(not animator.is_playing(), "Startup idle must not replace a retained death pose.")
    assert(display.get_node("UI Elements/Status").modulate.a == 0)
    assert(is_equal_approx(absf(display.get_node("Appearance").rotation), PI / 2))
    await player.play_events(
        stage, [BattleCombatEvent.new(BattleCombatEvent.TYPE.REVIVED, request, foe)], func(): return true
    )
    assert(display.get_node("UI Elements/Status").modulate.a == 1)
    await free_node(player)


## Exercises actual production displays without installing a debug presentation
## adapter. Assets are temporary/silent; this verifies dispatch, not artistic QA.
func _test_effect_dispatch(stage: BattleVisualStage, ally: BattleUnit, foe: BattleUnit) -> void:
    assert(not BattleController.get_unit_display(ally))
    var display := stage.get_unit_display(ally)
    var animator: AnimationPlayer = display.get_node("%Animator")
    var library := AnimationLibrary.new()
    for suffix in ["left", "right"]:
        var animation := Animation.new()
        animation.length = 2.0
        animation.loop_mode = Animation.LOOP_LINEAR
        library.add_animation("test_" + suffix, animation)
    animator.add_animation_library(&"probe", library)
    var animation_template := EffectTemplateTriggerAnimation.new()
    animation_template.id = &"production_animation_probe"
    animation_template.template_scene = load(
        "res://GrimDaysBattle/scenes/battle/effects/effect_trigger_animation.tscn"
    )
    animation_template.animation_id = &"probe/test_"
    # Permanent allies are parented under the party, not an "Allies" node.
    await _apply_visual_effect(ally, ally, animation_template)
    assert(animator.current_animation == &"probe/test_left")
    await _apply_visual_effect(foe, ally, animation_template)
    assert(animator.current_animation == &"probe/test_right")
    ally.add_team_override(self, &"foes")
    await _apply_visual_effect(ally, ally, animation_template)
    assert(animator.current_animation == &"probe/test_left", "Allegiance must not change display facing.")
    ally.remove_team_override(self)
    animation_template.animation_id = &"missing_animation"
    await _apply_visual_effect(ally, ally, animation_template)
    # A looping animation has no completion; effects must still have returned.
    animator.stop()
    animator.remove_animation_library(&"probe")
    var sound_template = load("res://GrimDaysBattle/scripts/Effects/Resources/effect_trigger_sound.gd").new() # lint:ignore load-in-var,line-length -- Load fixtures during test execution.
    sound_template.id = &"production_sound_probe"
    sound_template.template_scene = load(
        "res://GrimDaysBattle/scenes/battle/effects/effect_trigger_sound.tscn"
    )
    var sound := AudioStreamWAV.new()
    var silence := PackedByteArray()
    silence.resize(22050)
    silence.fill(128)
    sound.data = silence
    sound_template.sound = sound
    sound_template.volume_db = -80.0
    var sound_count := display.get_children().filter(func(child): return child is AudioStreamPlayer).size()
    await _apply_visual_effect(ally, ally, sound_template)
    assert(display.get_children().filter(func(child): return child is AudioStreamPlayer).size() == sound_count + 1)
    var particle_template = ( # lint:ignore load-in-var -- Load fixtures during test execution.
        load("res://GrimDaysBattle/scripts/Effects/Resources/effect_spawn_particles.gd").new()
    )
    particle_template.id = &"production_particle_probe"
    particle_template.template_scene = load(
        "res://GrimDaysBattle/scenes/battle/effects/effect_spawn_particles.tscn"
    )
    var node := Node2D.new()
    node.name = &"ParticleProbe"
    var scene := PackedScene.new()
    assert(scene.pack(node) == OK)
    node.free()
    particle_template.particle_scene = scene
    particle_template.lifetime_seconds = 0.05
    var holder := display.get_node("Generic Particles")
    var count := holder.get_child_count()
    particle_template.starting_offset = Vector2(17, -23)
    var effect := ally.add_effect(ally, ally, particle_template, {"defer_application": true})
    var started := Time.get_ticks_msec()
    effect.apply()
    assert(not effect.finished, "Production particles must hold resolution for their lifetime.")
    assert(holder.get_child_count() == count + 1)
    assert(holder.get_child(-1).position == particle_template.starting_offset)
    await effect.applied
    assert(Time.get_ticks_msec() - started >= 40, "Particle resolution must wait for the lifetime timer.")
    effect.remove()
    var expiry_check := get_tree().create_timer(0.1)
    # Deliberately stall so both short timers can expire in the same frame.
    OS.delay_msec(120)
    await expiry_check.timeout
    # Both timers can expire in the same slow frame. queue_free is deferred.
    await get_tree().process_frame
    assert(holder.get_child_count() == count, "Production display must own particle expiry.")
    started = Time.get_ticks_msec()
    await _apply_visual_effect(ally, ally, particle_template)
    assert(Time.get_ticks_msec() - started >= 40, "The effect director must await particle resolution.")
    particle_template.lifetime_seconds = 0.0
    await _apply_visual_effect(ally, ally, particle_template)
    holder.get_child(-1).queue_free()


## Ordered cues mutate presentation only, are bounded even with looping/missing
## clips, and stop immediately when their continuation is cancelled.
func _test_event_playback(stage: BattleVisualStage, ally: BattleUnit, foe: BattleUnit) -> void:
    var player := BattleCombatPresentation.new()
    player.cue_seconds = 0.01
    player.sequence_seconds = 0.08
    add_child(player)
    var seen: Array[StringName] = []
    player.cue_started.connect(func(kind, _unit, _id): seen.append(kind))
    var action := BASIC_ATTACK.duplicate() as ActionTemplate
    action.attack_animation = &"idle"  # Looping: no animation_finished signal.
    var request := BattleActionRequest.new(&"visual_events", ally, action, [foe])
    var health: float = foe.get_stat(CombatStats.STATS.Health).Current
    var display := stage.get_unit_display(foe)
    var floating: FloatingTextController = display.get_node("UI Elements/Floating Text Controller")
    assert(not SignalBus.damaged.is_connected(floating.on_damaged))
    assert(not SignalBus.received_crit.is_connected(display.on_critical_damage))
    await player.attack(stage, request, func(): return true)
    var events: Array = []
    for type in [
        BattleCombatEvent.TYPE.CRITICAL,
        BattleCombatEvent.TYPE.DAMAGE,
        BattleCombatEvent.TYPE.HEALING,
        BattleCombatEvent.TYPE.MISS,
        BattleCombatEvent.TYPE.DEFEAT,
        BattleCombatEvent.TYPE.REVIVED
    ]:
        events.append(BattleCombatEvent.new(type, request, foe, 3))
    await player.play_events(stage, events, func(): return true)
    assert(seen == [&"attack", &"critical", &"damage", &"healing", &"miss", &"defeat", &"revived"])
    assert(foe.get_stat(CombatStats.STATS.Health).Current == health, "Playback cannot apply damage again.")
    assert(display.get_node("UI Elements/Status").modulate.a == 1, "Revival restores defeated HUD opacity.")
    assert(display.get_node("Appearance").rotation == 0)
    seen.clear()
    await player.play_events(stage, [events[4]], func(): return true)
    assert(display.get_node("UI Elements/Status").modulate.a == 0, "Death must retain its final pose.")
    await player.play_events(stage, [events[5]], func(): return true)
    var running := {"active": true}
    var cancel := func(_kind, _unit, _id): running.active = false
    player.cue_started.connect(cancel, CONNECT_ONE_SHOT)
    seen.clear()
    await player.play_events(stage, events, func(): return running.active)
    assert(seen.size() == 1, "Cancellation must suppress all later cues.")
    seen.clear()
    action.attack_animation = &"missing_attack_asset"
    await player.attack(stage, request, func(): return true)
    assert(seen == [&"attack"], "Missing assets must finish without a completion signal.")
    await free_node(player)


## Runs one cosmetic operation through the real unit manager. Queued instant
## instances are still valid in this frame, allowing completion to be asserted.
func _apply_visual_effect(source: BattleUnit, target: BattleUnit, template: EffectTemplate) -> void:
    template.trigger = CombatEffects.TRIGGER.TARGETED
    var effect := target.add_effect(source, target, template, {"defer_application": true})
    assert(effect)
    await target.resolve_effects(CombatEffects.TRIGGER.TARGETED)
    assert(effect.finished, "Presentation effect must complete its resolution contract.")


## Checks target selection using test objects and assertions. A failed assertion identifies behavior
## that no longer meets the test’s expectation.
func _test_target_selection(
    coordinator: BattleCoordinator,
    stage: BattleVisualStage,
    ally: BattleUnit,
    foe: BattleUnit,
) -> void:
    var token := coordinator.session_id
    coordinator.turn_order.begin_round([ally])
    var local_targets: Array[BattleUnit] = []
    var global_targets: Array[BattleUnit] = []
    var collect_global := func(unit: BattleUnit): global_targets.append(unit)
    var collect_local := func(sent_token: int, unit: BattleUnit):
        assert(sent_token == token)
        local_targets.append(unit)
    SignalBus.add_target.connect(collect_global)
    stage.target_added.connect(collect_local)
    assert(stage.select_targets(token, ally, BASIC_ATTACK))
    var display := stage.get_unit_display(foe)
    assert(display.mouse_trigger.visible)
    assert(not stage.get_unit_display(ally).mouse_trigger.visible)
    display.targeting_controller.add_unit(foe)
    assert(local_targets == [foe] and global_targets.is_empty())
    stage.clear_target_selection(token)
    display.targeting_controller.add_unit(foe)
    assert(local_targets == [foe], "Input after selection closes must not advance an action.")
    assert(not display.mouse_trigger.visible)
    assert(display.targeting_controller.skill_selected == null)
    # Local views must ignore legacy selection broadcasts.
    SignalBus.action_selected.emit(BASIC_ATTACK)
    assert(not display.mouse_trigger.visible)
    SignalBus.add_target.disconnect(collect_global)
    stage.target_added.disconnect(collect_local)
    var movement_completions: Array[StringName] = []
    var global_completions: Array[StringName] = []
    var actor_display := stage.get_unit_display(ally)
    var on_local_move := func(_actor: BattleUnit, _target: BattleUnit, request: StringName):
        movement_completions.append(request)
    var on_global_move := func(_actor: BattleUnit, _target: BattleUnit, request: StringName):
        global_completions.append(request)
    actor_display.movement_finished.connect(on_local_move)
    SignalBus.unit_moved_towards_unit.connect(on_global_move)
    var before := actor_display.global_position
    await actor_display.on_move_towards_unit(ally, foe, &"local_move")
    assert(actor_display.global_position != before, "Movement must use the injected display lookup.")
    assert(movement_completions == [&"local_move"] and global_completions.is_empty())
    actor_display.movement_finished.disconnect(on_local_move)
    SignalBus.unit_moved_towards_unit.disconnect(on_global_move)
    await get_tree().process_frame


## A named Animator owns cleanup for every root type, independently of the resolution timer.
func _test_particle_animations(display: Unit2DDisplay, unit: BattleUnit) -> void:
    for root: Node in [Node2D.new(), AnimatedSprite2D.new(), CPUParticles2D.new(), GPUParticles2D.new()]:
        root.name = &"NamedParticle"
        if root is Node2D:
            root.position = Vector2(4, 7)
        if root is CPUParticles2D or root is GPUParticles2D:
            root.one_shot = true
            root.lifetime = 0.01
        var animator := AnimationPlayer.new()
        animator.name = &"Animator"
        root.add_child(animator)
        animator.owner = root
        animator.unique_name_in_owner = true
        var library := AnimationLibrary.new()
        var clip := Animation.new()
        clip.length = 1.0
        library.add_animation(&"burst", clip)
        animator.add_animation_library(&"", library)
        var scene := PackedScene.new()
        assert(scene.pack(root) == OK)
        root.free()
        display.on_spawn_battle_particles(unit, scene, 0.01, &"named_probe", &"burst", Vector2(99, 99))
        var instance := display.get_node("Generic Particles").get_child(-1)
        var player := instance.get_node("%Animator") as AnimationPlayer
        assert(player.current_animation == &"burst")
        assert(instance.position == Vector2(4, 7), "Named animations suppress starting_offset.")
        player.pause()
        player.animation_finished.emit(&"unrelated")
        await get_tree().create_timer(0.03).timeout
        assert(
            is_instance_valid(instance) and not instance.is_queued_for_deletion(),
            "Neither lifetime nor root completion may free a named-animation scene."
        )
        player.play(&"burst")
        player.advance(1.1)
        assert(instance.is_queued_for_deletion(), "The requested animation must free the entire scene.")
        await get_tree().process_frame


## Explicit animation effects can use Animator on Spine displays; automatic cues still skip it.
func _test_spine_animation_skip(stage: BattleVisualStage, ally: BattleUnit, foe: BattleUnit) -> void:
    var display := stage.get_unit_display(ally)
    var original := display.spine_appearance
    var marker := SpineSpriteOverride.new()
    display.spine_appearance = marker
    var animator: AnimationPlayer = display.get_node("%Animator")
    animator.stop()
    var acknowledgements: Array[StringName] = []
    var collect := func(_unit: Variant, _animation: StringName, completed_request: StringName):
        acknowledgements.append(completed_request)
    SignalBus.played_battle_animation.connect(collect)
    display.on_play_battle_animation(ally, &"RESET", &"spine_animator")
    assert(animator.is_playing() and acknowledgements.is_empty())
    animator.advance(0.1)
    await get_tree().process_frame
    SignalBus.played_battle_animation.disconnect(collect)
    assert(acknowledgements == [&"spine_animator"], "Legacy effects still acknowledge actual completion.")
    assert(stage._effect_presentation.present(&"animation", {"animation_id": &"idle"}, ally))
    assert(animator.is_playing() and animator.current_animation == &"idle")
    animator.stop()
    var player := BattleCombatPresentation.new()
    player.cue_seconds = 1.0
    add_child(player)
    var request := BattleActionRequest.new(&"spine_skip", ally, BASIC_ATTACK, [foe])
    var token := player._begin(stage)
    var completed: Array[bool] = []
    var run_cue := func():
        await player._animate(ally, ally, &"idle", &"attack", request.request_id, token, func(): return true, 1.0)
        completed.append(true)
    run_cue.call()
    assert(completed == [true], "Spine cues must finish without awaiting their animation delay.")
    player._reset_display(display)
    display.play_idle_if_needed()
    assert(not animator.is_playing(), "Spine displays must skip reset and idle playback.")
    await free_node(player)
    display.spine_appearance = original
    marker.free()


## Routes action/effect settings unchanged, waits one cycle, and skips unavailable clips.
func _test_spine_playback(stage: BattleVisualStage, ally: BattleUnit, foe: BattleUnit) -> void:
    var display := stage.get_unit_display(ally)
    var original := display.spine_appearance
    var probe := SpineProbe.new()
    display.spine_appearance = probe
    var animator: AnimationPlayer = display.get_node("%Animator")
    animator.stop()
    var action := BASIC_ATTACK.duplicate() as ActionTemplate
    action.attack_animation = &"probe_"
    action.use_spine = true
    action.loop = true
    action.track_number = 2
    var player := BattleCombatPresentation.new()
    player.cue_seconds = 0.0
    add_child(player)
    var request := BattleActionRequest.new(&"spine_action", ally, action, [foe])
    var started := Time.get_ticks_msec()
    await player.attack(stage, request, func(): return true)
    assert(Time.get_ticks_msec() - started >= 150, "Spine actions use clip length, not cue_seconds.")
    assert(probe.calls == [{"name": "probe_", "loop": true, "track": 2}])
    assert(not animator.is_playing())
    # Production passes this same context into the resolver after the action wind-up.
    var timing := BattleActionContext.new()
    probe.seconds = 1.0
    started = Time.get_ticks_msec()
    await player.attack(stage, request, func(): return true, timing)
    var elapsed := Time.get_ticks_msec() - started
    assert(elapsed >= 680 and elapsed < 950, "Action must release resolution at 70 percent.")
    assert(timing.pending_animation_deadline > Time.get_ticks_msec())
    await timing.finish_animation(self)
    assert(Time.get_ticks_msec() - started >= 990)
    probe.seconds = 0.2
    var text_controller: FloatingTextController
    for child in stage.get_unit_display(foe).find_children("*", "", true, false):
        if child is FloatingTextController:
            text_controller = child
    assert(text_controller)
    var text_count := text_controller.get_child_count()
    var damage_event := BattleCombatEvent.new(BattleCombatEvent.TYPE.DAMAGE, request, foe, 1.0)
    player.present_result(stage, damage_event)
    assert(text_controller.get_child_count() == text_count + 1, "Damage feedback must appear immediately.")
    player.present_result(stage, damage_event)
    assert(text_controller.get_child_count() == text_count + 1, "Later playback must not duplicate feedback.")
    probe.calls.remove_at(probe.calls.size() - 1)
    var template := EffectTemplateTriggerAnimation.new()
    template.id = &"spine_effect_probe"
    template.template_scene = preload(
        "res://GrimDaysBattle/scenes/battle/effects/effect_trigger_animation.tscn"
    )
    template.animation_id = &"probe_"
    template.use_spine = true
    template.track_number = 3
    for looping in [false, true]:
        template.loop = looping
        started = Time.get_ticks_msec()
        await _apply_visual_effect(ally, ally, template)
        assert(
            Time.get_ticks_msec() - started >= 150,
            (
                "Spine effect elapsed %s ms, looping=%s, calls=%s."
                % [Time.get_ticks_msec() - started, looping, probe.calls.size()]
            )
        )
        assert(probe.calls.back() == {"name": "probe_", "loop": looping, "track": 3})
    # The legacy display path uses the same duration without its five-second signal timeout.
    var previous_adapter := BattleController.presentation_adapter
    var previous_dispatch := ally.presentation_request
    BattleController.set_presentation_adapter(
        BattleVisualPresentationAdapter.new(stage.ally_holder, stage.foe_holder, null)
    )
    ally.presentation_request = Callable()
    started = Time.get_ticks_msec()
    await _apply_visual_effect(ally, ally, template)
    assert(Time.get_ticks_msec() - started >= 150)
    ally.presentation_request = previous_dispatch
    BattleController.set_presentation_adapter(previous_adapter)
    var count := probe.calls.size()
    action.attack_animation = &"missing"
    template.animation_id = &"missing"
    await player.attack(stage, request, func(): return true)
    await _apply_visual_effect(ally, ally, template)
    assert(probe.calls.size() == count, "Missing names must never be passed to play_animation.")
    display.spine_appearance = null
    action.attack_animation = &"probe_"
    template.animation_id = &"probe_"
    await player.attack(stage, request, func(): return true)
    await _apply_visual_effect(ally, ally, template)
    assert(probe.calls.size() == count and not animator.is_playing())
    # Cancellation must release the action promptly even for a long looping Spine clip.
    display.spine_appearance = probe
    probe.seconds = 30.0
    var completed: Array[bool] = []
    var run_attack := func():
        await player.attack(stage, request, func(): return true)
        completed.append(true)
    run_attack.call()
    assert(completed.is_empty())
    player.cancel()
    await get_tree().process_frame
    assert(completed == [true])
    await free_node(player)
    display.spine_appearance = original
    probe.free()


## Critical/miss feedback must be visible at impact, before the carried Spine tail resolves.
func _test_immediate_outcomes(stage: BattleVisualStage, ally: BattleUnit, foe: BattleUnit) -> void:
    var display := stage.get_unit_display(ally)
    var target_display := stage.get_unit_display(foe)
    var original_spine := display.spine_appearance
    var original_target_spine := target_display.spine_appearance
    var probe := SpineProbe.new()
    probe.seconds = 1.0
    display.spine_appearance = probe
    var player := BattleCombatPresentation.new()
    player.cue_seconds = 0.2
    add_child(player)
    var resolver := BattleActionResolver.new()
    add_child(resolver)
    var floating: FloatingTextController = target_display.get_node("UI Elements/Floating Text Controller")
    var attack_particle: AnimatedSprite2D = display.get_node("%Critical Attack")
    var hit_particle: AnimatedSprite2D = target_display.get_node("%Critical Hit")
    var hit := EffectScalingCombatStatChangeTemplate.new()
    hit.id = &"feedback_hit"
    hit.template_scene = preload("res://GrimDaysBattle/scenes/battle/effects/effect_scaled_stat_change.tscn")
    hit.trigger = CombatEffects.TRIGGER.DAMAGED
    hit.target = CombatActions.TARGET.FOE
    hit.lifetime = EffectTemplate.LIFETIME.INSTANT
    hit.stat = CombatStats.STATS.Health
    hit.scales_with = CombatStats.STATS.Health
    hit.scales_from_sender = true
    hit.scales_by = -0.001
    hit.damage_type = CombatDamage.TYPE.True
    hit.critical_chance_bonus = 100.0
    var rank := RankTemplate.new()
    rank.effects = EffectTemplates.new()
    rank.effects.all.assign([hit])
    var action := ActionTemplate.new()
    action.id = &"feedback_timing"
    action.target = CombatActions.TARGET.FOE
    action.attack_animation = &"probe_"
    action.use_spine = true
    action.ranks = RanksTemplate.new()
    action.ranks.all.assign([rank])
    assert(ally.learn_action(action))
    for miss in [false, true]:
        action.always_hits = not miss
        var accuracy := ally.get_stat(CombatStats.STATS.Accuracy)
        accuracy.add_modifier(
            UnitStatModifier.create(
                &"feedback_accuracy",
                &"feedback_test",
                CombatStats.STATS.Accuracy,
                UnitStatModifier.OPERATION.OVERRIDE,
                0
            )
        )
        var timing := BattleActionContext.new()
        var request := BattleActionRequest.new(&"feedback_timing", ally, action, [foe])
        var started := Time.get_ticks_msec()
        await player.attack(stage, request, func(): return true, timing)
        var outcomes: Array[int] = []
        var callback := func(event: BattleCombatEvent):
            var label_count := floating.get_child_count()
            player.present_result(stage, event)
            if event.type != (BattleCombatEvent.TYPE.MISS if miss else BattleCombatEvent.TYPE.CRITICAL):
                return
            outcomes.append(Time.get_ticks_msec() - started)
            assert(floating.get_child_count() == label_count + 1)
            var label := floating.get_child(-1) as Label
            assert(label.visible and label.modulate.a == 1.0)
            assert((label.get_child(0) as AnimationPlayer).current_animation_position == 0.0)
            if not miss:
                assert(attack_particle.is_playing() and hit_particle.is_playing())
                assert(attack_particle.frame == 0 and hit_particle.frame == 0)
            player.present_result(stage, event)
            assert(floating.get_child_count() == label_count + 1, "Live feedback must not duplicate.")
        resolver.operation_resolved.connect(callback)
        var result: BattleActionResolution = await resolver.resolve(request, func(): return true, timing)
        resolver.operation_resolved.disconnect(callback)
        assert(result.success and outcomes.size() == 1)
        assert(outcomes[0] >= 680 and outcomes[0] < 950, "Feedback must occur at the 70 percent impact.")
        assert(Time.get_ticks_msec() - started >= 990, "Feedback must not shorten the full animation cycle.")
        var count := floating.get_child_count()
        # All these events were presented live, so the fallback pass must create no labels.
        player.cue_seconds = 0.0
        await player.play_events(stage, result.events, func(): return true)
        assert(floating.get_child_count() == count)
        accuracy.remove_modifiers_from_source(&"feedback_test")

    # A fallback batch must show all outcomes before its first bounded animation wait.
    display.spine_appearance = null
    target_display.spine_appearance = null
    player.cue_seconds = 0.2
    var fallback_request := BattleActionRequest.new(&"feedback_fallback", ally, action, [foe])
    var events: Array = []
    for type in [BattleCombatEvent.TYPE.DAMAGE, BattleCombatEvent.TYPE.MISS, BattleCombatEvent.TYPE.CRITICAL]:
        events.append(BattleCombatEvent.new(type, fallback_request, foe, 1))
    var fallback_count := floating.get_child_count()
    var completed: Array[bool] = []
    var play := func():
        await player.play_events(stage, events, func(): return true)
        completed.append(true)
    play.call()
    assert(completed.is_empty() and floating.get_child_count() == fallback_count + 3)
    assert(attack_particle.is_playing() and hit_particle.is_playing())
    attack_particle.frame = 4
    hit_particle.frame = 4
    player.present_result(stage, events[2])
    assert(attack_particle.frame == 4 and hit_particle.frame == 4, "Fallback must not replay critical particles.")
    while completed.is_empty():
        await get_tree().process_frame
    display.spine_appearance = original_spine
    target_display.spine_appearance = original_target_spine
    probe.free()
    await free_node(resolver)
    await free_node(player)
