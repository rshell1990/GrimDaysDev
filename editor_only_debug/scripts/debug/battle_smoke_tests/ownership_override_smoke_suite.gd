extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"

## Script loaded for control effect script; reused instead of looking up the file on each call.
const CONTROL_EFFECT_SCRIPT := preload(
    "res://GrimDaysBattle/scripts/Effects/Runtime/effect_control_override.gd"
)
## Script loaded for team effect script; reused instead of looking up the file on each call.
const TEAM_EFFECT_SCRIPT := preload("res://GrimDaysBattle/scripts/Effects/Runtime/effect_team_override.gd")


## Runs the ownership override smoke checks. Creates or uses test objects and stops on failed
## assertions.
func run() -> void:
    var unit := create_unit()
    var ally := create_unit()
    create_flat_stat(unit, CombatStats.STATS.Health, 10.0)
    create_flat_stat(ally, CombatStats.STATS.Health, 10.0)
    unit.player_controlled = true
    unit.team_id = &"allies"
    ally.team_id = &"allies"
    assert(not CombatActions.valid_target(BASIC_ATTACK, ally, unit))
    var control_template := EffectControlOverrideTemplate.new()
    control_template.player_controlled = false
    var control_effect = CONTROL_EFFECT_SCRIPT.new()
    control_effect.name = &"control_override_test"
    control_effect.setup(unit, unit, control_template)
    add_child(control_effect)
    control_effect.apply()
    assert(not unit.player_controlled)
    await _remove_effect(control_effect)
    assert(unit.player_controlled, "Removing a control effect must restore base ownership.")

    var charm_template := EffectTeamOverrideTemplate.new()
    charm_template.team_id = &"foes"
    var charm = TEAM_EFFECT_SCRIPT.new()
    charm.name = &"charm_team_override_test"
    charm.setup(unit, unit, charm_template)
    add_child(charm)
    charm.apply()
    assert(unit.team_id == &"foes")
    assert(CombatActions.valid_target(BASIC_ATTACK, ally, unit), "Team overrides must affect target validity.")
    var neutral_template := EffectTeamOverrideTemplate.new()
    neutral_template.team_id = &"neutral"
    var neutral = TEAM_EFFECT_SCRIPT.new()
    neutral.name = &"neutral_team_override_test"
    neutral.setup(unit, unit, neutral_template)
    add_child(neutral)
    neutral.apply()
    assert(unit.team_id == &"neutral", "Newest team override must take precedence.")
    await _remove_effect(neutral)
    assert(unit.team_id == &"foes", "Removing the newest override must reveal the prior source.")
    await _remove_effect(charm)
    assert(unit.team_id == &"allies", "Removing every override must restore base affiliation.")
    assert(not CombatActions.valid_target(BASIC_ATTACK, ally, unit))
    await free_node(ally)
    await free_node(unit)


## Removes the effect and waits until its node leaves the scene tree.
func _remove_effect(effect: EffectBase) -> void:
    effect.remove()
    await effect.tree_exited
