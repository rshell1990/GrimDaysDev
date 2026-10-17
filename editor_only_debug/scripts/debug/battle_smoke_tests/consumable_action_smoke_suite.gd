extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"
## Exercises item use through the real production menu, targeting and turn flow.

const ENCOUNTER := preload("res://GrimDaysBattle/scenes/battle/production_encounter.tscn")
## Authored foe template used by the production consumable fixture.
const HARLOK := preload("res://GrimDaysBattle/resources/units/harlok/harlok_battle_unit_template.tres")
## Runtime resource-change effect scene used by the test potion.
const RESOURCE_SCENE := preload("res://GrimDaysBattle/scenes/battle/effects/effect_change_resource.tscn")


class IsolatedParty:
    extends BattlePartyManager

    func _ready() -> void:
        pass


## Checks owned-item choices, targeting, consumption, effects, turn completion and rejection of
## reused or outdated item requests.
func run() -> void:
    var party := IsolatedParty.new()
    add_child(party)
    var actor := BattleUnit.create(CELINE_TEMPLATE)
    var ally := BattleUnit.create(HARLOK)
    for unit in [actor, ally]:
        party.add_child(unit)
        party.runtime_units[unit.template_resource.id] = unit
        party.active_party_ids.append(unit.template_resource.id)
        _override(unit, CombatStats.STATS.Health, 100)
    _override(actor, CombatStats.STATS.Swiftness, 100)
    _override(ally, CombatStats.STATS.Swiftness, 10)
    var heal := EffectResourceChangeTemplate.new()
    heal.id = &"item_heal"
    heal.stat = CombatStats.STATS.Health
    heal.amount = 25
    heal.kind = CombatEffects.KIND.ONCE
    heal.template_scene = RESOURCE_SCENE
    heal.trigger = CombatEffects.TRIGGER.DAMAGED
    heal.target = CombatActions.TARGET.ALLY
    var potion := ConsumableTemplate.new()
    potion.id = &"item_test_potion"
    potion.display_name = "Test Potion"
    potion.stack_size = 5
    potion.usable_in_battle = true
    potion.battle_actions.assign(
        [
            _action(&"potion_self", CombatActions.TARGET.SELF, heal),
            _action(&"potion_ally", CombatActions.TARGET.ALLY, heal)
        ]
    )
    assert(party.stash.add_item(ItemBase.create(potion, 5)))
    assert(BattleItemAction.available(actor).is_empty(), "Stash supplies must not be combat choices.")
    assert(actor.inventory.add_item(ItemBase.create(potion, 2)))
    var choices := BattleItemAction.available(actor)
    assert(choices.size() == 2 and not ally.can_use_action(choices[0]))
    potion.usable_in_battle = false
    assert(BattleItemAction.available(actor).is_empty() and not actor.can_use_action(choices[0]))
    potion.usable_in_battle = true
    # Replacing a stack invalidates old selections even if the same template remains.
    assert(actor.inventory.add_item_to_slot(1, ItemBase.create(potion, 2)))
    assert(not actor.can_use_action(choices[0]))
    var scene: BattleEncounterScene = ENCOUNTER.instantiate()
    add_child(scene)
    assert(scene.begin_encounter(party, [HARLOK, HARLOK], &"item_production", 71))
    for foe in scene.coordinator.roster.get_foes():
        _override(foe, CombatStats.STATS.Swiftness, 1)
        _override(foe, CombatStats.STATS.Health, 100)
        foe.get_stat(CombatStats.STATS.Health).restore_current(100)
    ally.get_stat(CombatStats.STATS.Health).restore_current(40)
    # A damage reaction must not run just because a potion uses the effect runner.
    var reaction := heal.duplicate() as EffectResourceChangeTemplate
    reaction.id = &"item_not_an_attack"
    reaction.amount = -5
    reaction.damage_type = CombatDamage.TYPE.True
    reaction.trigger = CombatEffects.TRIGGER.DAMAGED
    reaction.lifetime = EffectTemplate.LIFETIME.UNTIL_BATTLE_END
    ally.add_effect(actor, ally, reaction, {"defer_application": true})
    await _wait_action(scene.flow)
    assert(scene.flow.active_unit == actor)
    var menu: BattleActionMenu = scene.get_node("Interface/ActionMenu")
    var wheel: BattleActionWheel = scene.stage.get_unit_display(actor).get_node("UI Elements/Action Wheel")
    while not wheel._accepting:
        await get_tree().process_frame
    wheel.get_node("Items").pressed.emit()
    assert(wheel.items.visible and wheel.items.get_child_count() == 9)
    assert(wheel.items.get_child(0).text.contains("Test Potion"))
    assert(wheel.items.get_child(0).text.contains("x2"))
    wheel.items.get_child(0).pressed.emit()
    assert(wheel.items.get_child_count() == 2, "One inventory slot preserves both authored targeting modes.")
    var item_action: BattleItemAction
    for choice in scene.flow._available_actions():
        if choice is BattleItemAction and choice.target == CombatActions.TARGET.ALLY:
            item_action = choice
    assert(item_action)
    var input_turn := scene.flow.turn_id
    assert(scene.flow.choose_action(input_turn, item_action))
    menu.back.pressed.emit()
    assert(scene.flow.state == BattleEncounterFlow.STATE.ACTION and actor.inventory.slots[1].count == 2)
    var blocker_definition := reaction.duplicate() as EffectResourceChangeTemplate
    blocker_definition.id = &"item_sealed"
    blocker_definition.trigger = CombatEffects.TRIGGER.TARGETED
    var blocker := actor.add_effect(actor, actor, blocker_definition, {"defer_application": true})
    assert(not actor.can_use_action(item_action))
    var blocked_request := BattleActionRequest.new(&"blocked_item", actor, item_action, [ally])
    var blocked: BattleActionResolution = await scene.flow._resolver.resolve(blocked_request)
    assert(not blocked.success and actor.inventory.slots[1].count == 2)
    blocker.remove()
    assert(actor.can_use_action(item_action))
    var energy: float = actor.get_stat(CombatStats.STATS.Energy).Current
    var resolutions: Array[BattleActionResolution] = []
    scene.flow.action_completed.connect(func(result): resolutions.append(result))
    assert(scene.flow.choose_action(input_turn, item_action))
    scene.stage.get_unit_display(ally).targeting_controller.add_unit(ally)
    assert(not scene.flow.choose_action(input_turn, item_action))
    var deadline := Time.get_ticks_msec() + 5000
    while resolutions.is_empty() and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    assert(resolutions.size() == 1 and resolutions[0].success)
    assert(actor.inventory.slots[1].count == 1 and party.stash.slots[1].count == 5)
    assert(ally.get_stat(CombatStats.STATS.Health).Current == 65, "Potion heals once without damage-reaction passives.")
    assert(actor.get_stat(CombatStats.STATS.Energy).Current == energy)
    assert(actor.get_action_cooldown(item_action) == 0 and not actor.is_action_learned(item_action))
    var used: int = 0
    var healed: int = 0
    for event in resolutions[0].events:
        if event.type == BattleCombatEvent.TYPE.ITEM_USED:
            used += 1
            assert(event.data.item_id == potion.id)
        if event.type == BattleCombatEvent.TYPE.HEALING:
            healed += 1
        assert(event.type not in [BattleCombatEvent.TYPE.HIT, BattleCombatEvent.TYPE.MISS])
    assert(used == 1 and healed == 1 and not actor.can_use_action(item_action))
    assert(
        heal.trigger == CombatEffects.TRIGGER.DAMAGED and heal.target == CombatActions.TARGET.ALLY,
        "Item execution preserves authored effect routing."
    )
    await _wait_action(scene.flow)
    assert(scene.flow.turn_id > input_turn and scene.flow.active_unit != actor, "Item use spends the normal turn.")
    scene.flow.stop()
    await _test_validation_and_area(scene, actor, potion)
    _test_stack_restore(actor, potion)
    _test_resource_round_trips(potion)
    scene.cancel_session()
    await free_node(scene)
    await free_node(party)


## Rejected targets do not consume supplies. One area use consumes only one item,
## applies once per recipient, retains attribution, and cannot be replayed.
func _test_validation_and_area(scene: BattleEncounterScene, actor: BattleUnit, potion: ConsumableTemplate) -> void:
    var self_action: ActionTemplate = BattleItemAction.available(actor)[0]
    var foes := scene.coordinator.roster.get_foes()
    var invalid := BattleActionRequest.new(&"invalid_item_target", actor, self_action, [foes[0]])
    var rejected: BattleActionResolution = await scene.flow._resolver.resolve(invalid)
    assert(not rejected.success and actor.inventory.slots[1].count == 1)
    var bomb := potion.duplicate(true) as ConsumableTemplate
    bomb.id = &"item_test_bomb"
    var damage := (
        potion.battle_actions[0].get_rank_template(1).effects.all[0].duplicate() as EffectResourceChangeTemplate
    )
    damage.amount = -10
    damage.damage_type = CombatDamage.TYPE.True
    bomb.battle_actions.assign([_action(&"bomb_foes", CombatActions.TARGET.FOES, damage)])
    assert(actor.inventory.add_item(ItemBase.create(bomb)))
    var area_action: BattleItemAction
    for action in BattleItemAction.available(actor):
        if action.item == bomb:
            area_action = action
    assert(area_action)
    var request := BattleActionRequest.new(&"area_item_use", actor, area_action, foes)
    var result: BattleActionResolution = await scene.flow._resolver.resolve(request)
    assert(result.success and actor.inventory.slots[2] == null)
    assert(
        result.events.any(func(event): return event.type == BattleCombatEvent.TYPE.HIT),
        "Damaging items use normal action hit resolution."
    )
    for foe in foes:
        assert(foe.get_stat(CombatStats.STATS.Health).Current == 90 and foe.last_hit_by == actor)
    var replay: BattleActionResolution = await scene.flow._resolver.resolve(request)
    assert(not replay.success, "Consumed selections cannot pay/apply twice.")
    var malformed := potion.duplicate(true) as ConsumableTemplate
    malformed.id = &"item_invalid_empty"
    malformed.battle_actions = []
    assert(actor.inventory.add_item(ItemBase.create(malformed)))
    assert(BattleItemAction.available(actor).size() == 2, "Empty action definitions are not usable actions.")


## Sets a test unit’s effective stat through a modifier, without editing its authored template.
func _override(unit: BattleUnit, stat: CombatStats.STATS, amount: float) -> void:
    unit.get_stat(stat).add_modifier(
        UnitStatModifier.create(
            StringName("item_test:%s" % stat), &"item_test", stat, UnitStatModifier.OPERATION.OVERRIDE, amount
        )
    )


## Waits for the production flow to request player input and fails if it does not become ready
## within the test’s limit.
func _wait_action(flow: BattleEncounterFlow) -> void:
    var deadline := Time.get_ticks_msec() + 5000
    while flow.state != BattleEncounterFlow.STATE.ACTION and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    assert(flow.state == BattleEncounterFlow.STATE.ACTION)


## Deliberately expensive and multi-rank: inventory execution ignores these costs and rank two.
func _action(action_id: StringName, target_mode: CombatActions.TARGET, effect: EffectTemplate) -> ActionTemplate:
    var action := ActionTemplate.new()
    action.id = action_id
    action.display_name = "Test Potion - %s" % CombatActions.TARGET.keys()[target_mode].capitalize()
    action.target = target_mode
    action.target_amount = 1
    action.always_hits = true
    action.disabled_by_effects = [&"item_sealed"]
    var rank := RankTemplate.new()
    rank.cost[CombatStats.STATS.Energy] = 99999
    rank.cooldown_turns = 9
    rank.effects = EffectTemplates.new()
    rank.effects.all.assign([effect])
    action.ranks = RanksTemplate.new()
    var later_rank := rank.duplicate(true) as RankTemplate
    (later_rank.effects.all[0] as EffectResourceChangeTemplate).amount = 1000
    action.ranks.all.assign([rank, later_rank])
    return action


## Save/retry restoration invalidates old choices; shared definitions do not share consumption.
func _test_stack_restore(actor: BattleUnit, potion: ConsumableTemplate) -> void:
    actor.inventory.clear_items()
    assert(actor.inventory.add_item_to_slot(1, ItemBase.create(potion, 2)))
    assert(actor.inventory.add_item_to_slot(2, ItemBase.create(potion, 2)))
    var choices := BattleItemAction.available(actor)
    assert(choices.size() == 4)
    var first: BattleItemAction = choices[0]
    var other: BattleItemAction = choices[2]
    assert(first.definition == other.definition and first != other)
    first.disabled_by_effects.clear()
    assert(not other.disabled_by_effects.is_empty() and not first.definition.disabled_by_effects.is_empty())
    var saved := actor.inventory.capture_state()
    assert(first.consume(actor) and not first.consume(actor))
    assert(other.can_use(actor) and actor.inventory.slots[2].count == 2)
    assert(actor.inventory.restore_state(JSON.parse_string(JSON.stringify(saved)), {potion.id: potion}).is_empty())
    assert(not other.can_use(actor) and actor.inventory.capture_state() == saved)
    var checkpoint := BattleRetryCheckpoint.new()
    checkpoint.capture([actor])
    var before_retry: BattleItemAction = BattleItemAction.available(actor)[0]
    assert(before_retry.consume(actor))
    assert(checkpoint.restore())
    assert(not before_retry.can_use(actor) and actor.inventory.capture_state() == saved)


## Round trips retain action data and public resource identities after subclass retirement.
func _test_resource_round_trips(potion: ConsumableTemplate) -> void:
    var path := "user://action_migration_round_trip.tres"
    assert(ResourceSaver.save(potion, path) == OK)
    var restored := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as ConsumableTemplate
    assert(restored and restored.id == potion.id and restored.battle_actions.size() == 2)
    assert(restored.battle_actions[0].get_rank_template(1).cost[CombatStats.STATS.Energy] == 99999)
    assert(restored.battle_actions[0].get_rank_template(1).effects.all[0].amount == 25)
    DirAccess.remove_absolute(path)
    var identities := {
        "res://GrimDaysBattle/resources/actions/celine/straight_punch/straight_punch.tres":
        "uid://k71gidtn7rnw",
        "res://GrimDaysBattle/resources/actions/celine/dark_urges_single_rank/dark_urges_single_rank.tres":
        "uid://dx03a8juy4xpp",
        "res://GrimDaysBattle/resources/actions/_basic/_basic_attack/basic_attack.tres": "",
    }
    for source_path: String in identities:
        # Deliberate uncached loads verify serialized script references, not editor cache instances.
        var original := ResourceLoader.load(source_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as ActionTemplate
        assert(original and original.get_script().get_global_name() == &"ActionTemplate")
        if not identities[source_path].is_empty():
            assert(ResourceUID.id_to_text(ResourceLoader.get_resource_uid(source_path)) == identities[source_path])
        assert(ResourceSaver.save(original, path) == OK)
        var copy := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as ActionTemplate
        assert(copy and copy.id == original.id and copy.ranks.all.size() == original.ranks.all.size())
        DirAccess.remove_absolute(path)
