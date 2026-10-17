# Stun consumes a pending player turn, expires by rounds, and permits normal control afterwards.
extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/production_flow_smoke_suite.gd"


func run() -> void:
    var f := _fixture([HARLOK], CELINE_TEMPLATE, false)
    var flow: BattleEncounterFlow = f.scene.flow
    await _wait_for_action(flow)
    var actor: BattleUnit = f.ally
    var before := flow.turn_id
    var stun := EffectStunTemplate.new()
    stun.id = &"pending_turn_stun"
    var applied := actor.add_effect(actor, actor, stun)
    assert(actor.is_stunned())
    assert(not flow.choose_command(before, CombatActions.COMMAND.DEFEND))
    assert(not actor.can_use_action(actor.get_basic_action()))
    for frame in 1200:
        if flow.turn_id > before:
            break
        await get_tree().process_frame
    assert(flow.turn_id > before, "Stun must spend the pending turn without waiting for player input.")
    if is_instance_valid(applied):
        applied.remove()
    assert(not actor.is_stunned() and actor.player_controlled)
    f.scene.cancel_session()
    f.scene.queue_free()
    f.party.queue_free()
    await f.party.tree_exited
    print("STUN_FLOW_SMOKE_SUITE: PASS") # lint:ignore debug-print -- Required test/CLI output.
