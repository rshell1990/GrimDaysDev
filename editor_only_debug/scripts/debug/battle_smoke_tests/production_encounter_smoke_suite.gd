extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"

## Script loaded for coordinator; reused instead of looking up the file on each call.
const COORDINATOR := preload("res://GrimDaysBattle/scripts/Battle/Runtime/battle_coordinator.gd")


# No global reset/save registration: these tests must not replace the live party.
class IsolatedParty:
    extends BattlePartyManager

    func _ready() -> void:
        pass


## Runs the production encounter smoke checks. Creates or uses test objects and stops on failed
## assertions.
func run() -> void:
    var party := IsolatedParty.new()
    add_child(party)
    var ally := BattleUnit.create(CELINE_TEMPLATE)
    party.add_child(ally)
    party.runtime_units[CELINE_TEMPLATE.id] = ally
    party.active_party_ids = [CELINE_TEMPLATE.id]
    ally.team_id = &"exploration"
    ally.player_controlled = false
    var tree_exits: Array[bool] = []
    ally.tree_exiting.connect(func(): tree_exits.append(true))
    var strength := ally.get_stat(CombatStats.STATS.Strength)
    var initial_strength: float = strength.Current
    var persistent := (
        ally
        . add_effect(
            ally,
            ally,
            _stat_grant(
                &"permanent_training",
                5.0,
                EffectTemplate.LIFETIME.PERSISTENT,
            )
        )
    )
    assert(persistent and is_equal_approx(strength.Current, initial_strength + 5.0))
    var weapon_action := BASIC_ATTACK.duplicate(true) as ActionTemplate
    weapon_action.id = &"encounter_test_weapon_action"
    var weapon := EquipmentWeaponTemplate.new()
    weapon.id = &"encounter_test_weapon"
    weapon.equips_to = [UnitEquipmentSlot.SLOT.LeftHand]
    weapon.basic_action_template = weapon_action
    weapon.on_equip_effects = [
        _stat_grant(
            &"weapon_strength",
            3.0,
            EffectTemplate.LIFETIME.WHILE_SOURCE_ACTIVE,
        )
    ]
    var equipped := await ally.equip_item(weapon, UnitEquipmentSlot.SLOT.LeftHand)
    assert(equipped)
    var granted_strength: float = strength.Current
    assert(is_equal_approx(granted_strength, initial_strength + 8.0))
    var coordinator := COORDINATOR.new()
    add_child(coordinator)
    var finished: Array[BattleResult] = []
    coordinator.battle_finished.connect(func(_token: int, result: BattleResult): finished.append(result))
    assert(not coordinator.begin_encounter(party, [], &"invalid"))
    assert(not coordinator.begin_encounter(party, [null], &"invalid"))
    assert(coordinator.roster.get_participants().is_empty())
    assert(ally.get_parent() == party and tree_exits.is_empty())
    var previous_token: int = -1
    var first_roll: int = 0
    for encounter_index in range(2):
        assert(
            (
                coordinator
                . begin_encounter(
                    party,
                    [CELINE_TEMPLATE],
                    &"repeat_encounter",
                    431,
                    {"event_id": "story"},
                    {"experience": 10},
                )
            )
        )
        var token: int = coordinator.session_id
        assert(not coordinator.begin_encounter(party, [CELINE_TEMPLATE], &"overlap"))
        var competing := COORDINATOR.new()
        add_child(competing)
        assert(not competing.begin_encounter(party, [CELINE_TEMPLATE], &"competing"))
        assert(competing.roster.get_participants().is_empty())
        await free_node(competing)
        assert(not coordinator.get_save_block_reason().is_empty())
        assert(coordinator.roster.get_allies() == [ally])
        var roster_copy := coordinator.roster.get_allies()
        roster_copy.clear()
        assert(coordinator.roster.get_allies() == [ally], "Roster access must not expose mutable membership.")
        var foe: BattleUnit = coordinator.roster.get_foes()[0]
        assert(foe.get_parent() == coordinator.roster and foe != ally)
        assert(ally.get_parent() == party and tree_exits.is_empty())
        assert(ally.player_controlled and ally.team_id == &"allies")
        assert(ally.get_basic_action() == weapon_action)
        assert(is_equal_approx(strength.Current, granted_strength))
        var roll: int = ally.randomizer.random_number_generator.randi()
        if encounter_index == 0:
            first_roll = roll
        else:
            assert(roll == first_roll, "Encounter seeding must reset each participant's stream.")
            assert(not coordinator.cleanup(previous_token))
            assert(coordinator.finish(previous_token, BattleResult.OUTCOME.VICTORY) == null)
            assert(not coordinator.begin_round(previous_token))
        assert(coordinator.begin_round(token))
        assert(coordinator.record_turn_started(token))
        assert(coordinator.turn_order.get_active_unit() != null)
        (
            ally
            . add_effect(
                ally,
                ally,
                _stat_grant(
                    &"battle_boost",
                    2.0,
                    EffectTemplate.LIFETIME.UNTIL_BATTLE_END,
                )
            )
        )
        assert(is_equal_approx(strength.Current, granted_strength + 2.0))
        var result := coordinator.finish(token, BattleResult.OUTCOME.VICTORY)
        assert(result and result.finalized and result.rounds == 1 and result.turns == 1)
        assert(result.encounter_id == &"repeat_encounter" and result.rewards == {"experience": 10})
        assert(result.return_context == {"event_id": "story"})
        assert(coordinator.finish(token, BattleResult.OUTCOME.DEFEAT) == result)
        assert(finished.size() == encounter_index + 1)
        assert(not coordinator.record_turn_started(token))
        assert(is_equal_approx(strength.Current, granted_strength))
        assert(coordinator.cleanup(token))
        assert(not coordinator.cleanup(token))
        assert(coordinator.get_save_block_reason().is_empty())
        await get_tree().process_frame
        assert(not is_instance_valid(foe), "Only encounter-owned opponents should be destroyed.")
        assert(ally.get_parent() == party and tree_exits.is_empty())
        assert(not ally.player_controlled and ally.team_id == &"exploration")
        assert(is_instance_valid(equipped) and is_instance_valid(persistent))
        assert(ally.get_basic_action() == weapon_action)
        assert(is_equal_approx(strength.Current, granted_strength))
        assert(not result.foe_snapshots.is_empty(), "Result values must survive foe cleanup.")
        previous_token = token
    _test_turn_order(coordinator, ally)
    _test_synchronous_cleanup(coordinator, party, finished)
    await _test_abandoned_scene(coordinator, party, ally, granted_strength)
    assert(tree_exits.is_empty(), "Deployment/cleanup must never take permanent allies out of the tree.")
    await ally.unequip_item(UnitEquipmentSlot.SLOT.LeftHand)
    assert(ally.get_basic_action() == BASIC_ATTACK)
    assert(is_equal_approx(strength.Current, initial_strength + 5.0))
    persistent.remove()
    assert(is_equal_approx(strength.Current, initial_strength))
    await free_node(party)


## Checks synchronous cleanup using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_synchronous_cleanup(
    coordinator: BattleCoordinator,
    party: BattlePartyManager,
    finished: Array[BattleResult],
) -> void:
    assert(coordinator.begin_encounter(party, [CELINE_TEMPLATE], &"synchronous_cleanup"))
    var on_finished := func(token: int, _result: BattleResult): assert(coordinator.cleanup(token))
    coordinator.battle_finished.connect(on_finished, CONNECT_ONE_SHOT)
    var result := coordinator.finish(coordinator.session_id, BattleResult.OUTCOME.DEFEAT)
    assert(result and result.is_defeat() and result.finalized)
    assert(finished.size() == 3 and finished.back() == result)
    assert(coordinator.current_result == null and coordinator.state == coordinator.STATE.IDLE)


## Checks turn order using test objects and assertions. A failed assertion identifies behavior that
## no longer meets the test’s expectation.
func _test_turn_order(coordinator: BattleCoordinator, ally: BattleUnit) -> void:
    var other := BattleUnit.create(CELINE_TEMPLATE)
    add_child(other)
    var order := coordinator.turn_order
    order.begin_round([ally, other, ally])
    assert(order.get_units() == [ally, other], "Speed ties preserve input order and omit duplicate units.")
    assert(order.remove_defeated([ally]) == [0])
    assert(order.get_active_unit() == other)
    order.advance()
    assert(order.get_active_unit() == null)
    other.queue_free()


## Checks abandoned scene using test objects and assertions. A failed assertion identifies behavior
## that no longer meets the test’s expectation.
func _test_abandoned_scene(
    coordinator: BattleCoordinator,
    party: BattlePartyManager,
    ally: BattleUnit,
    granted_strength: float,
) -> void:
    # A pre-existing override must not be mistaken for the base state or revoked.
    ally.add_team_override(self, &"guests")
    ally.add_control_override(self, true)
    assert(coordinator.begin_encounter(party, [CELINE_TEMPLATE], &"abandoned"))
    assert(ally.team_id == &"guests")
    assert(coordinator.roster.get_active_team(&"guests") == [ally])
    (
        ally
        . add_effect(
            ally,
            ally,
            _stat_grant(
                &"abandoned_boost",
                2.0,
                EffectTemplate.LIFETIME.UNTIL_BATTLE_END,
            )
        )
    )
    await free_node(coordinator)
    assert(ally.get_parent() == party)
    assert(is_equal_approx(ally.get_stat(CombatStats.STATS.Strength).Current, granted_strength))
    assert(ally.team_id == &"guests" and ally.player_controlled)
    ally.remove_team_override(self)
    ally.remove_control_override(self)
    assert(ally.team_id == &"exploration" and not ally.player_controlled)


## Sets [code]effect.id[/code] to [code]id[/code]; sets [code]effect.stat[/code] to
## [code]CombatStats.STATS.Strength[/code]; sets [code]effect.flat_amount[/code] to
## [code]amount[/code]. Returns [code]effect[/code].
func _stat_grant(id: StringName, amount: float, lifetime: EffectTemplate.LIFETIME) -> EffectFlatChangeStatTemplate:
    var effect := EffectFlatChangeStatTemplate.new()
    effect.id = id
    effect.stat = CombatStats.STATS.Strength
    effect.flat_amount = amount
    effect.lifetime = lifetime
    effect.kind = CombatEffects.KIND.ONCE
    effect.trigger = CombatEffects.TRIGGER.EQUIP
    effect.template_scene = STAT_EFFECT_SCENE
    return effect
