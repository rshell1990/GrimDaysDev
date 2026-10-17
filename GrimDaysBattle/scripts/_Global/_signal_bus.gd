extends Node

## Fixed battle round presentation group value shared by all signal bus instances.
const BATTLE_ROUND_PRESENTATION_GROUP: StringName = &"battle_round_presentation"

#region SIGNAL BUS
## Autoload to manage core signals throughout the game.
##
#endregion

#region SIGNALS

#region UNIT STATS AND EFFECTS
## Emit when a unit's attributes must change.
signal attribute_changed(owner: Node, stat: Variant, amount: int)
## Signals to effect managers to add an effect to the target.
signal add_effect(sender: Node, target: Node, effect: EffectTemplate)
## Signals to reset added stats, so that they can be recalculated.
signal reset_added(effect_owner: BattleUnit, stat_name: StringName)
## Signals that an item was equipped by a certain unit.
signal equipped(
    owner: BattleUnit, equipable_template: EquipmentTemplate, slot_name: UnitEquipmentSlot
)
## Signals than an item was unequipped by a certain unit.
signal remove_equipment(owner: BattleUnit, equipment: Equipable, slot_name: UnitEquipmentSlot)
## Emitted when damaged.
signal damaged(unit: BattleUnit, amount: int)
## Emitted when healed.
signal healed(unit: BattleUnit, amount: int)
## Emitted when dodged.
signal dodged(unit: BattleUnit)
## Emitted when pity triggered.
signal pity_triggered(unit: BattleUnit)
## Emitted when luck triggered.
signal luck_triggered(unit: BattleUnit)
## Emitted to notify listeners that preformed crit occurred.
signal preformed_crit(unit: BattleUnit)
## Emitted to notify listeners that received crit occurred.
signal received_crit(unit: BattleUnit)
## Emitted when died.
signal died(unit: BattleUnit)
#endregion

#region ROUND LIFECYCLE
## A tick triggers the duration of effects to decrease, ends the previous round
## when one was running, and starts the round identified by the request ID.
## The request ID lets optional presentation acknowledge the exact round it displayed.
signal tick(request_id: StringName)
## Signals that the optional round-start presentation has completed.
signal battle_round_presentation_finished(request_id: StringName)
#endregion

#region TURN ORDER AND BATTLE INIT
## Signal to dispatch a battle state signal for the BattleStateManager.
signal dispatch_battle_signal(event: StringName, cargo: Variant)
## Emitted to notify listeners that init turn order occurred.
signal init_turn_order(units: Array[BattleUnit])
## Emitted to notify listeners that init battlefield occurred.
signal init_battlefield(allies: Array[BattleUnitTemplate], foes: Array[BattleUnitTemplate])
## Emitted to notify listeners that ally added to party occurred.
signal ally_added_to_party(unit: BattleUnit)
## Emitted to notify listeners that get active unit occurred.
signal get_active_unit
## Emitted to notify listeners that set next unit occurred.
signal set_next_unit
## Emitted to notify listeners that send active unit occurred.
signal send_active_unit(unit: BattleUnit)
## Emitted to notify listeners that unit requested by index occurred.
signal unit_requested_by_index(unit: BattleUnit)
## Emitted to notify listeners that units removed from turn occurred.
signal units_removed_from_turn(units: Array[int])
## Emitted to notify listeners that finished turn order update occurred.
signal finished_turn_order_update
#endregion

#region TARGETING AND ACTION SELECTION
## Signal that the player controls are active.
signal battle_action_select
## Signal that the player controls are inactive.
signal battle_action_selected
## Signal that targeting controls should turn off.
signal target_selected
## Emitted when action selected.
signal action_selected(action: ActionTemplate)
## Emitted to notify listeners that target set occurred.
signal target_set
## Emitted to notify listeners that add target occurred.
signal add_target(unit: BattleUnit)
## Emitted to notify listeners that remove target occurred.
signal remove_target(unit: BattleUnit)
## Emitted to notify listeners that clear selected targets occurred.
signal clear_selected_targets
## Emitted to notify listeners that change target occurred.
signal change_target(old_target: BattleUnit, new_target: BattleUnit)
#endregion

#region MOVEMENT AND CAMERA
## Emitted to notify listeners that unit move to original position occurred.
signal unit_move_to_original_position(active: BattleUnit)
## Emitted to notify listeners that unit moved towards unit occurred.
signal unit_moved_towards_unit(unit: BattleUnit, target: BattleUnit, request_id: StringName)
## Emitted to notify listeners that switch to combat camera occurred.
signal switch_to_combat_camera(unit: BattleUnit)
## Emitted to notify listeners that switch away from combat camera occurred.
signal switch_away_from_combat_camera
#endregion

#region ANIMATION, PARTICLES, AND SOUND
## Emitted to notify listeners that play battle animation occurred.
signal play_battle_animation(target: Variant, animation_id: StringName, request_id: StringName)
## Emitted to notify listeners that played battle animation occurred.
signal played_battle_animation(target: Variant, animation_id: StringName, request_id: StringName)
## Emitted to notify listeners that spawn battle particles occurred.
signal spawn_battle_particles(
    target: Variant,
    particle_scene: PackedScene,
    lifetime_seconds: float,
    request_id: StringName,
    animation_name: StringName,
    starting_offset: Vector2,
)
## Emitted to notify listeners that spawned battle particles occurred.
signal spawned_battle_particles(target: Variant, request_id: StringName)
## Emitted to notify listeners that play battle sound occurred.
signal play_battle_sound(
    target: Variant,
    sound: AudioStream,
    volume_db: float,
    pitch_scale: float,
    request_id: StringName,
)
## Emitted to notify listeners that played battle sound occurred.
signal played_battle_sound(target: Variant, request_id: StringName)
#endregion

#endregion
