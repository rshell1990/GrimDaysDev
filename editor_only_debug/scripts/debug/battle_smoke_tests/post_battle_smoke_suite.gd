extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"
## Accepted-result recovery and loot snapshots through production session completion.

const ENCOUNTER := preload("res://GrimDaysBattle/scenes/battle/production_encounter.tscn")


class IsolatedParty:
    extends BattlePartyManager

    func _ready() -> void:
        pass


## Checks accepted results, recovery, rewards, overflow choices, summaries and cancellation.
func run() -> void:
    await _test_accepted(BattleResult.OUTCOME.VICTORY)
    await _test_accepted(BattleResult.OUTCOME.DEFEAT)
    await _test_reward_overflow()
    await _test_cancelled_overflow()
    await _test_cancelled_summary()


## Checks one accepted victory or defeat, including recovery, unchanged terminal snapshots and
## exactly-once completion.
func _test_accepted(outcome: BattleResult.OUTCOME) -> void:
    var party := IsolatedParty.new()
    add_child(party)
    var members: Array[BattleUnit] = []
    for index in 3:
        var definition := CELINE_TEMPLATE.duplicate() as BattleUnitTemplate
        definition.id = StringName("recovery_member_%s" % index)
        var unit := BattleUnit.create(definition)
        party.add_child(unit)
        for stat_id in [CombatStats.STATS.Energy, CombatStats.STATS.Mana, CombatStats.STATS.Lucidity]:
            if not unit.get_stat(stat_id):
                create_flat_stat(unit, stat_id, 100)
        party.runtime_units[definition.id] = unit
        members.append(unit)
        if index < 2:
            party.active_party_ids.append(definition.id)
    var scene: BattleEncounterScene = ENCOUNTER.instantiate()
    add_child(scene)
    var foe_definition := CELINE_TEMPLATE.duplicate() as BattleUnitTemplate
    foe_definition.experience_reward = 3
    assert(scene.begin_session(party, [foe_definition], &"recovery_session", 21, {}, {"experience": 7}))
    scene.flow.stop()
    var foe: BattleUnit = scene.coordinator.roster.get_foes()[0]
    assert(foe.inventory.add_item(ItemBase.create(Inventory.COINS_TEMPLATE, 9)))
    var gear := EquipmentTemplate.new()
    gear.id = &"recovery_loot_ring"
    gear.lootable = true
    gear.equips_to.assign([UnitEquipmentSlot.SLOT.LeftRing])
    BattleRepository.kinds[&"PostBattleSmoke"] = {gear.id: gear}
    await foe.equip_item(gear, UnitEquipmentSlot.SLOT.LeftRing)
    var gear_id: StringName = foe.get_equipment_slot(UnitEquipmentSlot.SLOT.LeftRing).equipped.item_instance_id
    for unit in members:
        unit.get_stat(CombatStats.STATS.Health).restore_current(0 if unit != members[1] else 2)
        for stat_id in [CombatStats.STATS.Energy, CombatStats.STATS.Mana, CombatStats.STATS.Lucidity]:
            unit.get_stat(stat_id).restore_current(0.5)
    foe.get_stat(CombatStats.STATS.Health).restore_current(0)
    var completed: Array[BattleResult] = []
    scene.encounter_completed.connect(func(completed_result): completed.append(completed_result))
    var token := scene.coordinator.session_id
    var result := scene.coordinator.finish(token, outcome)
    assert(not result.party_recovered, "Raw attempt notification does not perform accepted-result recovery.")
    await get_tree().process_frame
    assert(completed.is_empty() and result.party_recovered)
    assert(scene.awaiting_continue and scene.result_summary.visible)
    assert(not party.can_prepare_inventory() and not scene.get_save_block_reason().is_empty())
    assert(scene.result_summary.heading.text == ("Victory" if outcome == BattleResult.OUTCOME.VICTORY else "Defeat"))
    assert("Party after battle" in scene.result_summary.details.text)
    assert(
        (
            ("Experience: 10" if outcome == BattleResult.OUTCOME.VICTORY else "No rewards granted")
            in scene.result_summary.details.text
        )
    )
    assert(result.rewards_settled)
    assert(
        scene.coordinator.state == BattleCoordinator.STATE.IDLE,
        "Accepted settlement releases foes before continuation."
    )
    for unit in [members[0], members[1]]:
        assert(
            unit.get_stat(CombatStats.STATS.Experience).Base == (10 if outcome == BattleResult.OUTCOME.VICTORY else 0)
        )
    assert(members[2].get_stat(CombatStats.STATS.Experience).Base == 0)
    assert(party.stash.money == (9 if outcome == BattleResult.OUTCOME.VICTORY else 0))
    if outcome == BattleResult.OUTCOME.VICTORY:
        assert(party.stash.slots[1].instance_id == gear_id)
        assert(result.reward_receipt.experience_per_member == 10)
    else:
        assert(party.stash.slots[1] == null and result.reward_receipt.items.is_empty())
    assert(members[0].get_stat(CombatStats.STATS.Health).Current == 1)
    assert(members[1].get_stat(CombatStats.STATS.Health).Current == 2, "Surviving Health must not reset to 1.")
    for unit in [members[0], members[1]]:
        assert(unit.get_stat(CombatStats.STATS.Mana).Current == 0.5)
        for stat_id in [CombatStats.STATS.Energy, CombatStats.STATS.Lucidity]:
            assert(unit.get_stat(stat_id).Current == unit.get_stat(stat_id).Max)
    assert(members[2].get_stat(CombatStats.STATS.Health).Current == 0)
    assert(
        members[2].get_stat(CombatStats.STATS.Energy).Current == 0.5,
        "Undeployed party reserves do not receive battle recovery."
    )
    assert(result.ally_snapshots[0].health == 0 and not result.ally_snapshots[0].active)
    assert(result.recovered_party_snapshots[0].health == 1)
    assert(result.foe_snapshots[0].loot.size() == 2)
    assert(result.foe_snapshots[0].loot[0].count == 9)
    assert(result.foe_snapshots[0].loot[1].instance_id == gear_id)
    members[0].get_stat(CombatStats.STATS.Energy).restore_current(0)
    scene.coordinator.battle_finished.emit(token, result)
    assert(not BattlePartyRecovery.apply(result, members))
    assert(BattleRewardSettlement.apply(result, party, members).is_empty())
    await get_tree().process_frame
    assert(completed.is_empty() and members[0].get_stat(CombatStats.STATS.Energy).Current == 0)
    assert(not is_instance_valid(foe), "Foes must already be freed while the result summary is visible.")
    scene.continue_encounter(token - 1)
    assert(completed.is_empty())
    scene.result_summary.continue_button.pressed.emit()
    scene.result_summary.continue_button.pressed.emit()
    scene.continue_encounter(token)
    assert(completed.size() == 1 and party.can_prepare_inventory())
    scene.cancel_session()
    await get_tree().process_frame
    assert(not is_instance_valid(foe), "Encounter-owned foes must be freed on cleanup.")
    assert(result.foe_snapshots[0].loot[1].instance_id == gear_id, "Loot data must outlive foes.")
    assert(is_instance_valid(members[0]) and members[0].get_parent() == party)
    await free_node(scene)
    await free_node(party)
    BattleRepository.kinds.erase(&"PostBattleSmoke")


## Shared inventory choices are real UI requests. Overflow cannot partially pay
## XP/money, silently expand capacity, free foes early, or continue the story.
func _test_reward_overflow() -> void:
    var party := IsolatedParty.new()
    add_child(party)
    var ally := BattleUnit.create(CELINE_TEMPLATE)
    party.add_child(ally)
    party.runtime_units[CELINE_TEMPLATE.id] = ally
    party.active_party_ids.assign([CELINE_TEMPLATE.id])
    party.stash.size = 1
    party.stash.clear_items()
    var junk := ItemTemplate.new()
    junk.id = &"reward_junk"
    junk.display_name = "Junk"
    var prize := ItemTemplate.new()
    prize.id = &"reward_prize"
    prize.display_name = "Prize"
    prize.lootable = true
    BattleRepository.kinds[&"RewardOverflowSmoke"] = {junk.id: junk, prize.id: prize}
    assert(party.stash.add_item(ItemBase.create(junk)))
    var scene: BattleEncounterScene = ENCOUNTER.instantiate()
    add_child(scene)
    assert(scene.begin_session(party, [CELINE_TEMPLATE], &"overflow_session", 71, {}, {"experience": 5, "money": 3}))
    scene.flow.stop()
    var foe: BattleUnit = scene.coordinator.roster.get_foes()[0]
    assert(foe.inventory.add_item(ItemBase.create(prize, 2)))
    foe.get_stat(CombatStats.STATS.Health).restore_current(0)
    var completed: Array[BattleResult] = []
    scene.encounter_completed.connect(func(completed_result): completed.append(completed_result))
    var token := scene.coordinator.session_id
    var result := scene.coordinator.finish(token, BattleResult.OUTCOME.VICTORY)
    await get_tree().process_frame
    assert(scene.awaiting_reward_choices and scene.reward_inventory.visible)
    assert(not result.rewards_settled and not result.party_recovered)
    assert(completed.is_empty() and is_instance_valid(foe))
    assert(party.stash.size == 1 and party.stash.money == 0)
    assert(ally.get_stat(CombatStats.STATS.Experience).Base == 0)
    assert(not scene.get_save_block_reason().is_empty())
    assert(not party.transfer_item(&"", CELINE_TEMPLATE.id, 1))
    var old_button: Button = scene.reward_inventory._stored.get_child(0).get_child(1).get_child(0)
    old_button.pressed.emit()
    assert(party.stash.slots[1] == null)
    assert(party.stash.add_item(ItemBase.create(junk)))  # A stale slot click must not delete this replacement.
    old_button.pressed.emit()
    assert(party.stash.slots[1] != null)
    scene.reward_inventory.present(party.stash, result, token)
    scene.reward_inventory._stored.get_child(0).get_child(1).get_child(0).pressed.emit()
    scene.reward_inventory.collect.pressed.emit()
    assert(scene.awaiting_reward_choices and not result.rewards_settled, "Two prizes still exceed one empty slot.")
    assert(party.stash.money == 0 and is_instance_valid(foe))
    # Incoming rows are encounter money followed by two individual prize records.
    scene.reward_inventory._offered.get_child(1).get_child(1).get_child(0).pressed.emit()
    assert(result.discarded_rewards.get(1) == 1)
    scene.collect_rewards(token - 1)
    assert(not result.rewards_settled)
    var experience := ally.get_stat(CombatStats.STATS.Experience)
    var reentry := func(_stat, _old, _new): scene._finish_attempt(token, result)
    experience.value_changed.connect(reentry)
    scene.reward_inventory.collect.pressed.emit()
    experience.value_changed.disconnect(reentry)
    assert(completed.is_empty() and result.rewards_settled and scene.awaiting_continue)
    assert("Left behind: 1" in scene.result_summary.details.text)
    assert(experience.Base == 5 and party.stash.money == 3)
    assert(party.stash.size == 1 and party.stash.slots[1].id == prize.id)
    assert(result.foe_snapshots[0].loot.size() == 2, "Declining rewards never rewrites foe history.")
    scene.collect_rewards(token)
    assert(completed.is_empty() and experience.Base == 5)
    scene.result_summary.continue_button.pressed.emit()
    assert(completed.size() == 1 and experience.Base == 5)
    await get_tree().process_frame
    assert(not is_instance_valid(foe))
    # A mixed malformed/capacity failure must not expose invalid records to the UI.
    var invalid := BattleResult.new()
    invalid.set_rewards({"experience": 5, "items": [null, {"template_id": prize.id, "count": 1}]})
    invalid.finalize(BattleResult.OUTCOME.VICTORY, [ally], [])
    assert(not BattleRewardSettlement.apply(invalid, party, [ally]).is_empty())
    assert(not invalid.reward_capacity_blocked and not invalid.rewards_settled)
    assert(experience.Base == 5 and party.stash.money == 3)
    var gear := EquipmentTemplate.new()
    gear.id = &"reward_generated_gear"
    BattleRepository.kinds[&"RewardOverflowSmoke"][gear.id] = gear
    party.stash.size = 3
    party.stash.clear_items()
    var copies := BattleResult.new()
    copies.set_rewards({"items": [{"template_id": gear.id, "count": 2}]})
    copies.finalize(BattleResult.OUTCOME.VICTORY, [ally], [])
    assert(BattleRewardSettlement.apply(copies, party, [ally]).is_empty())
    assert(copies.reward_receipt.items.size() == 2)
    assert(copies.reward_receipt.items[0].instance_id == party.stash.slots[1].instance_id)
    assert(copies.reward_receipt.items[1].instance_id == party.stash.slots[2].instance_id)
    assert(copies.reward_receipt.items[0].instance_id != copies.reward_receipt.items[1].instance_id)
    var bad_definition := CELINE_TEMPLATE.duplicate() as BattleUnitTemplate
    bad_definition.experience_reward = 2147483648
    assert(not BattleUnitTemplateValidator.validate(bad_definition).is_empty())
    await free_node(scene)
    await free_node(party)
    BattleRepository.kinds.erase(&"RewardOverflowSmoke")


## Cancelling a pending inventory prompt invalidates late collection. Existing
## supplies and XP remain intact; no continuation is emitted for an abandoned run.
func _test_cancelled_overflow() -> void:
    var party := IsolatedParty.new()
    add_child(party)
    var ally := BattleUnit.create(CELINE_TEMPLATE)
    party.add_child(ally)
    party.runtime_units[CELINE_TEMPLATE.id] = ally
    party.active_party_ids.assign([CELINE_TEMPLATE.id])
    party.stash.add_item(ItemBase.create(Inventory.COINS_TEMPLATE, Inventory.COINS_TEMPLATE.stack_size))
    var scene: BattleEncounterScene = ENCOUNTER.instantiate()
    add_child(scene)
    assert(scene.begin_session(party, [CELINE_TEMPLATE], &"cancel_rewards", 9, {}, {"money": 1, "experience": 5}))
    scene.flow.stop()
    var completed: Array[BattleResult] = []
    scene.encounter_completed.connect(func(completed_result): completed.append(completed_result))
    var token := scene.coordinator.session_id
    var result := scene.coordinator.finish(token, BattleResult.OUTCOME.VICTORY)
    await get_tree().process_frame
    assert(scene.awaiting_reward_choices)
    scene.cancel_session()
    scene.collect_rewards(token)
    scene.reward_inventory.collect.pressed.emit()
    await get_tree().process_frame
    assert(completed.is_empty() and not result.rewards_settled)
    assert(ally.get_stat(CombatStats.STATS.Experience).Base == 0)
    assert(party.stash.money == Inventory.COINS_TEMPLATE.stack_size)
    assert(party.can_prepare_inventory() and not scene.reward_inventory.visible)
    await free_node(scene)
    await free_node(party)


## Cancellation after settlement keeps committed rewards, but late acknowledgement
## cannot advance the caller or retain the summary's temporary party reservation.
func _test_cancelled_summary() -> void:
    var party := IsolatedParty.new()
    add_child(party)
    var ally := BattleUnit.create(CELINE_TEMPLATE)
    party.add_child(ally)
    party.runtime_units[CELINE_TEMPLATE.id] = ally
    party.active_party_ids.assign([CELINE_TEMPLATE.id])
    var scene: BattleEncounterScene = ENCOUNTER.instantiate()
    add_child(scene)
    assert(scene.begin_session(party, [CELINE_TEMPLATE], &"cancel_summary", 9, {}, {"money": 1, "experience": 5}))
    scene.flow.stop()
    var completed: Array[BattleResult] = []
    scene.encounter_completed.connect(func(completed_result): completed.append(completed_result))
    var token := scene.coordinator.session_id
    var result := scene.coordinator.finish(token, BattleResult.OUTCOME.VICTORY)
    await get_tree().process_frame
    assert(scene.awaiting_continue and result.rewards_settled)
    scene.cancel_session()
    scene.result_summary.continue_button.pressed.emit()
    scene.continue_encounter(token)
    assert(completed.is_empty() and party.can_prepare_inventory())
    assert(party.stash.money == 1 and ally.get_stat(CombatStats.STATS.Experience).Base == 5)
    assert(not scene.result_summary.visible and scene.get_save_block_reason().is_empty())
    # Cancellation from a cleanup observer must not reopen an unacknowledgeable
    # summary or reacquire a party lease after the session was cancelled.
    assert(scene.begin_session(party, [CELINE_TEMPLATE], &"cancel_cleanup", 10))
    scene.flow.stop()
    scene.coordinator.battle_clearing.connect(func(_token): scene.cancel_session(), CONNECT_ONE_SHOT)
    scene.coordinator.finish(scene.coordinator.session_id, BattleResult.OUTCOME.VICTORY)
    await get_tree().process_frame
    assert(not scene.awaiting_continue and not scene.result_summary.visible)
    assert(completed.is_empty() and party.can_prepare_inventory())
    await free_node(scene)
    await free_node(party)
