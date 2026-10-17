extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"

## Script loaded for particle effect script; reused instead of looking up the file on each call.
const PARTICLE_EFFECT_SCRIPT := preload(
    "res://GrimDaysBattle/scripts/Effects/Runtime/effect_spawn_particles.gd"
)
## Script loaded for sound effect script; reused instead of looking up the file on each call.
const SOUND_EFFECT_SCRIPT := preload("res://GrimDaysBattle/scripts/Effects/Runtime/effect_trigger_sound.gd")
## Script loaded for sprite effect script; reused instead of looking up the file on each call.
const SPRITE_EFFECT_SCRIPT := preload("res://GrimDaysBattle/scripts/Effects/Runtime/effect_swap_sprite.gd")
## Script loaded for particle template script; reused instead of looking up the file on each call.
const PARTICLE_TEMPLATE_SCRIPT := preload(
    "res://GrimDaysBattle/scripts/Effects/Resources/effect_spawn_particles.gd"
)
## Script loaded for sound template script; reused instead of looking up the file on each call.
const SOUND_TEMPLATE_SCRIPT := preload(
    "res://GrimDaysBattle/scripts/Effects/Resources/effect_trigger_sound.gd"
)
## Script loaded for sprite template script; reused instead of looking up the file on each call.
const SPRITE_TEMPLATE_SCRIPT := preload(
    "res://GrimDaysBattle/scripts/Effects/Resources/effect_swap_sprite.gd"
)


## Runs the presentation effect smoke checks. Creates or uses test objects and stops on failed
## assertions.
func run() -> void:
    var unit := create_unit()
    _test_presentation_adapters(unit)
    await _test_headless_particle_effect(unit)
    await _test_headless_sound_effect(unit)
    _test_correlated_completions(unit)
    await _test_source_owned_sprite_swaps(unit)
    await free_node(unit)


## Checks presentation adapters using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_presentation_adapters(unit: BattleUnit) -> void:
    var immediate := BattleImmediatePresentationAdapter.new()
    assert(not immediate.is_visual())
    assert(immediate.deploy_unit(CELINE_TEMPLATE, &"allies") == null)
    assert(immediate.get_unit_display(unit) == null)

    var allies := Unit2DParty.new()
    var foes := Unit2DParty.new()
    var bounds := CollisionShape2D.new()
    var display := Unit2DDisplay.new()
    # This test covers adapter routing only; avoid invoking the display's UI-binding
    # setter on a deliberately childless fixture.
    display._unit_reference = unit
    allies.add_child(display)
    var visual := BattleVisualPresentationAdapter.new(allies, foes, bounds)
    assert(visual.is_visual())
    assert(visual.get_unit_display(unit) == display)
    var previous_presentation := BattleController.presentation_adapter
    BattleController.set_presentation_adapter(visual)
    assert(BattleController.get_unit_display(unit) == display)
    BattleController.clear_presentation_adapter(immediate)
    assert(BattleController.presentation_adapter == visual, "A stale scene must not clear the active adapter.")
    BattleController.clear_presentation_adapter(visual)
    assert(not BattleController.presentation_adapter.is_visual())
    BattleController.set_presentation_adapter(previous_presentation)
    visual.clear()
    assert(allies.get_child_count() == 0)
    allies.free()
    foes.free()
    bounds.free()


## Checks headless particle effect using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_headless_particle_effect(unit: BattleUnit) -> void:
    var particle_scene := PackedScene.new()
    var particle_node := Node2D.new()
    assert(particle_scene.pack(particle_node) == OK)
    particle_node.free()
    var template = PARTICLE_TEMPLATE_SCRIPT.new()
    template.id = &"headless_particles"
    template.particle_scene = particle_scene
    var effect = PARTICLE_EFFECT_SCRIPT.new()
    effect.name = template.id
    effect.setup(unit, unit, template)
    add_child(effect)
    effect.apply()
    assert(effect.finished, "Particle effects must complete immediately without an attached display.")
    await free_node(effect)


## Checks headless sound effect using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_headless_sound_effect(unit: BattleUnit) -> void:
    var template = SOUND_TEMPLATE_SCRIPT.new()
    template.id = &"headless_sound"
    template.sound = AudioStreamGenerator.new()
    var effect = SOUND_EFFECT_SCRIPT.new()
    effect.name = template.id
    effect.setup(unit, unit, template)
    add_child(effect)
    effect.apply()
    assert(effect.finished, "Sound effects must complete immediately without an attached display.")
    await free_node(effect)


## Checks correlated completions using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_correlated_completions(unit: BattleUnit) -> void:
    var other_target := BattleUnit.new()
    var particle_effect = PARTICLE_EFFECT_SCRIPT.new()
    particle_effect.targeting = unit
    particle_effect.request_id = &"particles:test:1"
    particle_effect.on_particles_spawned(other_target, &"particles:test:1")
    particle_effect.on_particles_spawned(unit, &"particles:test:stale")
    assert(not particle_effect.finished, "Particle acknowledgements must match target and request ID.")
    particle_effect.on_particles_spawned(unit, &"particles:test:1")
    assert(particle_effect.finished)
    particle_effect.free()

    var sound_effect = SOUND_EFFECT_SCRIPT.new()
    sound_effect.targeting = unit
    sound_effect.request_id = &"sound:test:1"
    sound_effect.on_sound_played(other_target, &"sound:test:1")
    sound_effect.on_sound_played(unit, &"sound:test:stale")
    assert(not sound_effect.finished, "Sound acknowledgements must match target and request ID.")
    sound_effect.on_sound_played(unit, &"sound:test:1")
    assert(sound_effect.finished)
    sound_effect.free()
    other_target.free()


## Checks source owned sprite swaps using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_source_owned_sprite_swaps(unit: BattleUnit) -> void:
    var base_scene := _make_sprite_scene(&"BaseSprite")
    var first_scene := _make_sprite_scene(&"FirstSwap")
    var second_scene := _make_sprite_scene(&"SecondSwap")
    unit.default_battle_sprite = base_scene

    var first_template = SPRITE_TEMPLATE_SCRIPT.new()
    first_template.id = &"first_sprite_swap"
    first_template.sprite_scene = first_scene
    var first_effect = SPRITE_EFFECT_SCRIPT.new()
    first_effect.name = first_template.id
    first_effect.setup(unit, unit, first_template)
    add_child(first_effect)
    first_effect.apply()
    assert(first_effect.finished)
    assert(unit.get_battle_sprite() == first_scene)

    var second_template = SPRITE_TEMPLATE_SCRIPT.new()
    second_template.id = &"second_sprite_swap"
    second_template.sprite_scene = second_scene
    var second_effect = SPRITE_EFFECT_SCRIPT.new()
    second_effect.name = second_template.id
    second_effect.setup(unit, unit, second_template)
    add_child(second_effect)
    second_effect.apply()
    assert(unit.get_battle_sprite() == second_scene, "The newest sprite override must take precedence.")
    await free_node(second_effect)
    assert(unit.get_battle_sprite() == first_scene, "Removing a sprite override must reveal the prior source.")
    await free_node(first_effect)
    assert(unit.get_battle_sprite() == base_scene, "Removing every sprite override must restore the unit default.")

    var display := Unit2DDisplay.new()
    var sprite_holder := Node2D.new()
    display.add_child(sprite_holder)
    display.sprite_holder = sprite_holder
    display.on_battle_sprite_changed(first_scene)
    assert(display.appearance_scene and display.appearance_scene.name == &"FirstSwap")
    display.on_battle_sprite_changed(second_scene)
    assert(display.appearance_scene and display.appearance_scene.name == &"SecondSwap")
    display.free()


## Deletes [code]sprite[/code] immediately; sets [code]sprite.name[/code] to
## [code]sprite_name[/code]. Returns [code]scene[/code].
func _make_sprite_scene(sprite_name: StringName) -> PackedScene:
    var sprite := Unit2DSprite.new()
    var attack_particle := AnimatedSprite2D.new()
    attack_particle.name = &"AttackAnimation"
    sprite.add_child(attack_particle)
    attack_particle.owner = sprite
    sprite.attack_particle = attack_particle
    sprite.name = sprite_name
    var scene := PackedScene.new()
    assert(scene.pack(sprite) == OK)
    sprite.free()
    return scene
