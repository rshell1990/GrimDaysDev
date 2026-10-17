extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"


## Runs the action equipment smoke checks. Creates or uses test objects and stops on failed
## assertions.
func run() -> void:
    var unit := create_unit(CELINE_TEMPLATE)
    var strength := create_flat_stat(unit, CombatStats.STATS.Strength, 20.0)
    (
        strength
        . add_modifier(
            (
                UnitStatModifier
                . create(
                    &"strength_training_percent",
                    &"skill:strength_training",
                    CombatStats.STATS.Strength,
                    UnitStatModifier.OPERATION.PERCENT_ADD,
                    0.10,
                )
            )
        )
    )
    create_flat_stat(unit, CombatStats.STATS.Energy, 10.0)
    create_flat_stat(unit, CombatStats.STATS.PhysicalDamage, 40.0)
    create_flat_stat(unit, CombatStats.STATS.DamageModifier, 1.5)
    await _test_basic_attack(unit)
    _test_action_rules(unit)
    await _test_fixed_source_ranks()
    await _test_effect_restrictions()
    await _test_equipment_lifecycle(unit, strength)
    await free_node(unit)
    await _test_equipment_source_and_actor()
    await _test_loadout_persistence()


## Checks basic attack using test objects and assertions. A failed assertion identifies behavior
## that no longer meets the test’s expectation.
func _test_basic_attack(attacker: BattleUnit) -> void:
    attacker.randomizer.set_seed(5678)
    var expected_rng := RandomNumberGenerator.new()
    expected_rng.seed = 5678
    var expected_damage := roundi(45.0 * expected_rng.randf_range(0.85, 1.15))
    assert(
        CELINE_TEMPLATE.basic_action_template == BASIC_ATTACK, "Celine must use the canonical Basic Attack resource."
    )
    assert(attacker.get_action_rank(BASIC_ATTACK) == 1)
    assert(BASIC_ATTACK.get_rank_template(1) != null)
    assert(BASIC_ATTACK.get_effects_by_rank_and_trigger(1, CombatEffects.TRIGGER.DAMAGED).size() == 1)
    assert(BASIC_ATTACK.get_effects_by_rank_and_trigger(1, CombatEffects.TRIGGER.ATTACKING).is_empty())
    var target := create_unit()
    var health := create_flat_stat(target, CombatStats.STATS.Health, 100.0)
    create_flat_stat(target, CombatStats.STATS.PhysicalResistance, 25.0)
    var damage_events: Array[int]
    var on_damaged := func(damaged_unit: BattleUnit, amount: int) -> void:
        if damaged_unit == target:
            damage_events.append(amount)
    SignalBus.damaged.connect(on_damaged)
    var effects_added := (
        Combat
        . add_effects_from_category(
            BASIC_ATTACK,
            attacker,
            target,
            CombatEffects.TRIGGER.DAMAGED,
        )
    )
    assert(effects_added == 1, "Basic Attack must add exactly one damage effect to its target.")
    await target.resolve_effects(CombatEffects.TRIGGER.DAMAGED)
    assert(
        is_equal_approx(health.Current, 100.0 - expected_damage),
        "Basic Attack must resolve its authored physical damage."
    )
    assert(damage_events == [expected_damage], "Basic Attack must emit one event containing actual damage dealt.")
    SignalBus.damaged.disconnect(on_damaged)
    await free_node(target)


## Checks action rules using test objects and assertions. A failed assertion identifies behavior
## that no longer meets the test’s expectation.
func _test_action_rules(unit: BattleUnit) -> void:
    var first_rank := RankTemplate.new()
    first_rank.id = &"test_action_rank_1"
    first_rank.level = 1
    first_rank.cost = {CombatStats.STATS.Energy: 4}
    first_rank.cooldown_turns = 1
    first_rank.effects = EffectTemplates.new()
    var second_rank := first_rank.duplicate(true) as RankTemplate
    second_rank.id = &"test_action_rank_2"
    second_rank.level = 2
    var ranks := RanksTemplate.new()
    ranks.id = &"test_action_ranks"
    ranks.all = [first_rank, second_rank]
    var action := ActionTemplate.new()
    action.id = &"test_owned_action"
    action.ranks = ranks
    action.target = CombatActions.TARGET.SELF
    action.target_amount = 1
    assert(not unit.owns_action(action), "Authored resources are not automatically owned.")
    assert(unit.learn_action(action, 2))
    assert(unit.get_action_rank(action) == 2)
    assert(unit.can_use_action(action))
    assert(unit.pay_action_cost(action))
    assert(is_equal_approx(unit.get_stat(CombatStats.STATS.Energy).Current, 6.0))
    assert(not unit.can_use_action(action), "A paid action must enter its authored cooldown.")
    assert(not unit.pay_action_cost(action))
    assert(
        is_equal_approx(unit.get_stat(CombatStats.STATS.Energy).Current, 6.0), "Rejected actions cannot spend twice."
    )
    unit.on_turn_started()
    assert(not unit.can_use_action(action), "Cooldown one must block the unit's next turn.")
    unit.on_turn_started()
    assert(unit.can_use_action(action), "Cooldown must expire after its authored future turns.")
    unit.get_stat(CombatStats.STATS.Energy).decrease_current_flat(3.0)
    assert(not unit.can_use_action(action), "Actions must reject insufficient resource pools.")
    unit.forget_action(action)
    assert(not unit.owns_action(action))


## Checks equipment lifecycle using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_equipment_lifecycle(unit: BattleUnit, strength: UnitGenericStat) -> void:
    assert(unit.get_basic_action() == BASIC_ATTACK)
    var weapon_action := BASIC_ATTACK.duplicate(true) as ActionTemplate
    weapon_action.id = &"training_sword_attack"
    weapon_action.display_name = "Training Sword Attack"
    var strength_effect := EffectFlatChangeStatTemplate.new()
    strength_effect.id = &"training_sword_strength"
    strength_effect.stat = CombatStats.STATS.Strength
    strength_effect.flat_amount = 5.0
    strength_effect.lifetime = EffectTemplate.LIFETIME.WHILE_SOURCE_ACTIVE
    strength_effect.kind = CombatEffects.KIND.ONCE
    strength_effect.trigger = CombatEffects.TRIGGER.EQUIP
    strength_effect.template_scene = STAT_EFFECT_SCENE
    var weapon := EquipmentWeaponTemplate.new()
    weapon.id = &"training_sword"
    weapon.equips_to = [UnitEquipmentSlot.SLOT.LeftHand]
    weapon.on_equip_effects = [strength_effect]
    weapon.basic_action_template = weapon_action
    var action_changes: Array[ActionTemplate]
    var on_action_changed := func(action: ActionTemplate) -> void: action_changes.append(action)
    unit.basic_action_changed.connect(on_action_changed)
    var equipable: Equipable = await unit.equip_item(weapon, UnitEquipmentSlot.SLOT.LeftHand)
    assert(equipable != null, "A compatible weapon must be equipped into the requested slot.")
    assert(unit.get_basic_action() == weapon_action, "An equipped weapon must override Basic Attack.")
    assert(is_equal_approx(strength.Current, 27.5), "Equipment effects must modify stats through the effect manager.")
    await unit.unequip_item(UnitEquipmentSlot.SLOT.LeftHand)
    assert(unit.get_basic_action() == BASIC_ATTACK, "Unequipping a weapon must restore the default Basic Attack.")
    assert(is_equal_approx(strength.Current, 22.0), "Unequipping must remove only that equipment source's modifier.")
    assert(action_changes == [weapon_action, BASIC_ATTACK], "Equip and unequip must each publish the resulting action.")
    unit.basic_action_changed.disconnect(on_action_changed)


## Two copies own independent grants; the wearer, not the item node, is the
## sender for scaled/chained procs. Unequip must not remove unrelated unit effects.
func _test_equipment_source_and_actor() -> void:
    var unit := BattleUnit.create(CELINE_TEMPLATE)
    var foe := BattleUnit.create(CELINE_TEMPLATE)
    add_child(unit)
    add_child(foe)
    unit.last_target = foe
    foe.get_stat(CombatStats.STATS.Health).add_modifier(
        UnitStatModifier.create(
            &"proc_health", &"test:proc", CombatStats.STATS.Health, UnitStatModifier.OPERATION.OVERRIDE, 100
        )
    )
    var weight := unit.get_stat(CombatStats.STATS.Weight)
    var baseline := weight.Current
    var damage := EffectResourceChangeTemplate.new()
    damage.id = &"equipment_proc_damage"
    damage.template_scene = load("res://GrimDaysBattle/scenes/battle/effects/effect_change_resource.tscn")
    damage.stat = CombatStats.STATS.Health
    damage.amount = -1
    damage.damage_type = CombatDamage.TYPE.True
    damage.target = CombatActions.TARGET.LAST_HIT
    damage.trigger = CombatEffects.TRIGGER.AFTER_HITTING
    damage.lifetime = EffectTemplate.LIFETIME.INSTANT
    var chain := EffectTriggerAnotherEffect.new()
    chain.id = &"equipment_proc"
    chain.template_scene = load("res://GrimDaysBattle/scenes/battle/effects/effect_trigger_chain.tscn")
    chain.triggers = [damage]
    chain.trigger = CombatEffects.TRIGGER.AFTER_HITTING
    chain.lifetime = EffectTemplate.LIFETIME.WHILE_SOURCE_ACTIVE
    chain.kind = CombatEffects.KIND.REPEAT
    var item := EquipmentTemplate.new()
    item.id = &"proc_ring"
    item.equips_to = [UnitEquipmentSlot.SLOT.LeftRing, UnitEquipmentSlot.SLOT.RightRing]
    item.weight = 2
    item.after_hitting_effects = [chain]
    var heal := damage.duplicate() as EffectResourceChangeTemplate
    heal.id = &"equip_once_heal"
    heal.amount = 1
    heal.trigger = CombatEffects.TRIGGER.EQUIP
    item.on_equip_effects = [heal]
    var wearer_health := unit.get_stat(CombatStats.STATS.Health)
    wearer_health.decrease_current_flat(5)
    var wearer_before := wearer_health.Current
    var first := await unit.equip_item(item, UnitEquipmentSlot.SLOT.LeftRing)
    var second := await unit.equip_item(item, UnitEquipmentSlot.SLOT.RightRing)
    assert(wearer_health.Current == wearer_before + 2, "Instant OnEquip runs once per copy.")
    assert(first.item_instance_id != second.item_instance_id)
    assert(weight.Current == baseline + 4)
    var first_source := first.grant_source_id
    var second_source := second.grant_source_id
    assert(unit.effect_manager.get_effects_from_source(first_source)[0].sender == unit)
    var health := foe.get_stat(CombatStats.STATS.Health)
    var before := health.Current
    await unit.resolve_effects(CombatEffects.TRIGGER.AFTER_HITTING)
    assert(health.Current == before - 2 and foe.last_hit_by == unit)
    await unit.unequip_item(UnitEquipmentSlot.SLOT.LeftRing)
    assert(weight.Current == baseline + 2)
    assert(unit.effect_manager.get_effects_from_source(first_source).is_empty())
    assert(unit.effect_manager.get_effects_from_source(second_source).size() == 1)
    await unit.resolve_effects(CombatEffects.TRIGGER.AFTER_HITTING)
    assert(health.Current == before - 3)
    await unit.unequip_item(UnitEquipmentSlot.SLOT.RightRing)
    assert(weight.Current == baseline)
    await free_node(foe)
    await free_node(unit)


## Starting loadouts are authored, while saved slots/IDs are authoritative on
## reconstruction. Restore maximum grants before exact pools and weapon cooldowns.
func _test_loadout_persistence() -> void:
    var template := CELINE_TEMPLATE.duplicate(false) as BattleUnitTemplate
    var bonus := EffectFlatChangeStatTemplate.new()
    bonus.id = &"loadout_health"
    bonus.template_scene = STAT_EFFECT_SCENE
    bonus.stat = CombatStats.STATS.Health
    bonus.flat_amount = 20
    bonus.trigger = CombatEffects.TRIGGER.EQUIP
    bonus.lifetime = EffectTemplate.LIFETIME.WHILE_SOURCE_ACTIVE
    var instant := EffectResourceChangeTemplate.new()
    instant.id = &"no_replay_on_load"
    instant.template_scene = load("res://GrimDaysBattle/scenes/battle/effects/effect_change_resource.tscn")
    instant.stat = CombatStats.STATS.Health
    instant.amount = -1
    instant.damage_type = CombatDamage.TYPE.True
    instant.trigger = CombatEffects.TRIGGER.EQUIP
    instant.lifetime = EffectTemplate.LIFETIME.INSTANT
    var weapon_action := BASIC_ATTACK.duplicate() as ActionTemplate
    weapon_action.id = &"loadout_weapon_action"
    var weapon := EquipmentWeaponTemplate.new()
    weapon.id = &"loadout_weapon"
    weapon.equips_to = [UnitEquipmentSlot.SLOT.LeftHand]
    weapon.weight = 3
    weapon.on_equip_effects = [bonus, instant]
    weapon.basic_action_template = weapon_action
    template.equipment = EquipmentTemplateCollection.new()
    template.equipment.all = [weapon]
    var unit := BattleUnit.create(template)
    assert(unit != null)
    add_child(unit)
    var health := unit.get_stat(CombatStats.STATS.Health)
    assert(unit.get_basic_action() == weapon_action and unit.get_stat(CombatStats.STATS.Weight).Current == 3)
    health.restore_current(health.Max * 0.375)
    unit._action_cooldowns[weapon_action.id] = 3
    var party := BattlePartyManager.new()  # No _ready/reset side effects in this fixture.
    var saved := party._serialize_unit(unit)
    assert(saved.equipment.size() == 1)
    var saved_id: StringName = saved.equipment[0].instance_id
    var restored := BattleUnit.create(template, false)
    add_child(restored)
    assert(restored.get_equipment_slot(UnitEquipmentSlot.SLOT.LeftHand).equipped == null)
    var reports: Array[Dictionary] = []
    var record := func(report): reports.append(report)
    restored.resource_operation_resolved.connect(record)
    party._restore_unit(restored, saved)
    assert(reports.is_empty(), "Loading must not replay instant OnEquip operations.")
    assert(restored.get_equipment_slot(UnitEquipmentSlot.SLOT.LeftHand).equipped.item_instance_id == saved_id)
    assert(restored.get_basic_action() == weapon_action and restored.get_action_cooldown(weapon_action) == 3)
    assert(is_equal_approx(restored.get_stat(CombatStats.STATS.Health).Current, health.Current))
    assert(is_equal_approx(restored.get_stat(CombatStats.STATS.Health).Max, health.Max))
    party._restore_unit(restored, saved)
    assert(restored.get_stat(CombatStats.STATS.Weight).Current == 3, "Repeated load must not duplicate grants.")
    assert(is_equal_approx(restored.get_stat(CombatStats.STATS.Health).Max, health.Max))
    var invalid: Array = saved.equipment.duplicate(true)
    invalid.append(invalid[0].duplicate())
    assert(not BattleEquipmentLoadout.restore(restored, invalid).is_empty())
    assert(
        BattleEquipmentLoadout.capture(restored) == saved.equipment,
        "Invalid loadouts cannot partially replace equipment."
    )
    assert(not BattleEquipmentLoadout.restore(restored, [{"slot": "bad", "instance_id": 3}]).is_empty())
    await restored.unequip_item(UnitEquipmentSlot.SLOT.LeftHand)
    var empty := party._serialize_unit(restored)
    party._restore_unit(restored, empty)
    assert(restored.get_basic_action() == BASIC_ATTACK and restored.get_stat(CombatStats.STATS.Weight).Current == 0)
    assert(
        BattleEquipmentLoadout.capture(restored).is_empty(), "Empty saved loadout must not reapply starting defaults."
    )
    var invalid_template := template.duplicate(false) as BattleUnitTemplate
    invalid_template.equipment = EquipmentTemplateCollection.new()
    invalid_template.equipment.all = [weapon, weapon]
    assert(
        not BattleUnitTemplateValidator.validate(invalid_template).is_empty(), "Starting slot conflicts fail preflight."
    )
    party.free()
    await free_node(restored)
    await free_node(unit)


## Fixed action choices retain rank one independently of learned and automatic grants.
func _test_fixed_source_ranks() -> void:
    var definition := CELINE_TEMPLATE.duplicate() as BattleUnitTemplate
    var action := ActionTemplate.new()
    action.id = &"source_rank_regression"
    action.ranks = RanksTemplate.new()
    action.ranks.all = [RankTemplate.new(), RankTemplate.new()]
    definition.basic_action_template = action
    definition.special_action = action
    var unit := create_unit(definition)
    assert(unit.learn_action(action, 2))
    assert(unit.get_action_rank(action) == 1)
    assert(unit.get_action_rank(action, true) == 2, "Lucidity selects its grant rank explicitly.")
    var separately_authored := action.duplicate() as ActionTemplate
    assert(unit.get_action_rank(separately_authored) == 2, "An ID match alone is not a basic-action source.")
    var equipment_source := Node.new()
    add_child(equipment_source)
    unit.add_basic_action_override(equipment_source, separately_authored)
    assert(unit.get_action_rank(separately_authored) == 1)
    unit.remove_basic_action_override(equipment_source)
    assert(unit.get_action_rank(separately_authored) == 2)
    await free_node(equipment_source)
    await free_node(unit)


## Presence is evaluated at selection and commitment, independently of first trigger.
func _test_effect_restrictions() -> void:
    var unit := BattleUnit.create(CELINE_TEMPLATE)
    var other := BattleUnit.create(CELINE_TEMPLATE)
    add_child(unit)
    add_child(other)
    var action := ActionTemplate.new()
    action.id = &"restriction_test"
    action.target = CombatActions.TARGET.SELF
    action.ranks = RanksTemplate.new()
    action.ranks.all = [RankTemplate.new()]
    action.disabled_by_effects = [&"waiting_defense", &"waiting_defense"]
    assert(unit.learn_action(action))
    assert(unit.can_use_action(action))
    var definition := EffectFlatChangeStatTemplate.new()
    definition.id = &"waiting_defense"
    definition.stat = CombatStats.STATS.Strength
    definition.flat_amount = 1
    definition.trigger = CombatEffects.TRIGGER.TARGETED
    definition.lifetime = EffectTemplate.LIFETIME.WHILE_SOURCE_ACTIVE
    definition.template_scene = STAT_EFFECT_SCENE
    other.add_effect(other, other, definition, {"source_id": &"other"})
    assert(unit.can_use_action(action), "Only the actor's effects restrict a choice.")
    var selected := BattleActionRequest.new(&"stale_restriction", unit, action, [unit])
    var first := unit.add_effect(unit, unit, definition, {"source_id": &"first"})
    var second := unit.add_effect(unit, unit, definition, {"source_id": &"second"})
    assert(not first.applied_this_cycle and not unit.can_use_action(action))
    assert(not unit.pay_action_cost(action))
    var resolver := BattleActionResolver.new()
    add_child(resolver)
    assert(not (await resolver.resolve(selected)).success, "A stale selection cannot bypass a new blocker.")
    var option := LucidityBreakOption.new()
    option.action = action
    assert(option.validate().is_empty(), "Current blockers do not invalidate authored outcomes.")
    var template := CELINE_TEMPLATE.duplicate() as MainCharacterTemplate
    template.lucidity_break_options = [option]
    var monitor := BattleLucidityMonitor.new()
    assert(monitor._pick_option(template, unit) == null)
    var automatic := BattleActionRequest.new(&"restricted_lucidity", unit, action, [unit], true)
    assert(not (await resolver.resolve(automatic)).success)
    first.remove()
    assert(not unit.can_use_action(action), "Another live instance still blocks.")
    second.queue_free()
    assert(unit.can_use_action(action), "Queued effects stop blocking immediately.")
    assert(monitor._pick_option(template, unit) == option)
    assert((await resolver.resolve(automatic)).success)
    action.disabled_by_effects = [&""]
    assert(not action.validate_restrictions().is_empty())
    await free_node(resolver)
    await free_node(unit)
    await free_node(other)
