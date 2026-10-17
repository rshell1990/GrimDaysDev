extends Node


## Adds a whole story reward to a permanent unit's inventory without equipping it.
## Looks up an equipment repository ID; replay, battle locks and full storage fail unchanged.
func add_item_to_unit(unit_id: String, item_id: String, amount: int = 1) -> bool:
    if GameManager.in_replay:
        return false
    var party: BattlePartyManager = BattleController.party_manager
    if not is_instance_valid(party) or not party.can_prepare_inventory() or amount < 1:
        return false
    var unit: BattleUnit = party.runtime_units.get(StringName(unit_id))
    if not is_instance_valid(unit) or not is_instance_valid(unit.inventory):
        return false
    var definitions: Dictionary = BattleRepository.kinds.get(BattleRepository.BATTLE_EQUIPMENT, {})
    if item_id.is_empty() or not definitions.has(StringName(item_id)):
        return false
    var definition := BattleRepository.get_info(BattleRepository.BATTLE_EQUIPMENT, StringName(item_id)) as ItemTemplate
    if not definition or definition.id.is_empty() or definition.stack_size < 1:
        return false
    var accepted := unit.inventory.add_item(ItemBase.create(definition, amount))
    if not accepted:
        CustomLogger.warn(
            self,
            add_item_to_unit,
            "Could not add %s x%s to %s's inventory." % [definition.id, amount, unit_id],
            CustomLogger.LEVEL.IMPORTANT
        )
    return accepted


## Read-only choice condition against a permanent character's live, modified stat.
## Missing characters/stats, unsupported comparisons and nonfinite values fail closed.
func check_stat(unit_id: String, stat_name: String, comparison: String, threshold: float) -> bool:
    var party: BattlePartyManager = BattleController.party_manager
    if not is_instance_valid(party) or not CombatStats.STATS.has(stat_name) or not is_finite(threshold):
        return false
    var unit: BattleUnit = party.runtime_units.get(StringName(unit_id))
    if not is_instance_valid(unit):
        return false
    var stat := unit.get_stat(CombatStats.STATS[stat_name])
    if not stat or not is_finite(stat.Current):
        return false
    match comparison:
        ">=":
            return stat.Current >= threshold
        ">":
            return stat.Current > threshold
        "<=":
            return stat.Current <= threshold
        "<":
            return stat.Current < threshold
        "==":
            return stat.Current == threshold
        "!=":
            return stat.Current != threshold
    return false


## Story-authored level floor. Replaying/loading this Call cannot duplicate XP
## or unspent points; all grants/allocations remain in runtime party save state.
func ensure_party_unit_level(unit_id: String, level: int) -> bool:
    if GameManager.in_replay:
        return false
    var party: BattlePartyManager = BattleController.party_manager
    var accepted: bool = is_instance_valid(party) and party.ensure_minimum_level(StringName(unit_id), level)
    if not accepted:
        CustomLogger.warn(
            self,
            ensure_party_unit_level,
            "Could not apply story level milestone for %s at level %s." % [unit_id, level],
            CustomLogger.LEVEL.IMPORTANT
        )
    return accepted


## Looks up the supplied event ID and requests that the story event begin.
func trigger_event(id: String) -> void:
    var event = SystemAdministrators.find_event_by_id(id)
    if event == null:
        return
    VNSignalBus.event_found.emit(event)


## Sends the supplied message to the title-card display.
func show_title_card(message: String) -> void:
    UIDirector.show_title_card(message)


## Asks the title-card display to hide its current message.
func hide_title_card() -> void:
    UIDirector.hide_title_card()


## Shows the anger visual overlay.
func show_anger() -> void:
    UIDirector.show_anger()


## Passes the requested speed and transition duration to the anger visual effect.
func set_anger_speed(amount: float, transition_time: float) -> void:
    UIDirector.set_anger_speed(amount, transition_time)


## Passes the requested shake strength and transition speed to the screen-shake helper.
func shake_screen(strength: float, cycle_transition: float = 0.0) -> void:
    UIDirector.shake_screen(strength, cycle_transition)


## Hides the anger visual overlay.
func hide_anger() -> void:
    UIDirector.hide_anger()


## Requests that the scene-transition cover be hidden.
func hide_fade_flag() -> void:
    UIDirector.fade_flag_hide()


## Requests that the scene-transition cover be shown.
func show_fade_flag() -> void:
    UIDirector.fade_flag_show()


## Sends [code]VNSignalBus.play_animation[/code] notifications. It pauses for [code]it's finishing
## (" + str(await_finished) + ")",CustomLogger.LEVEL.MILD)[/code] before continuing.
func start_animation(anim_name: String, await_finished: bool = true) -> void:
    CustomLogger.hint(
        self,
        self.start_animation,
        (
            "is emitting the **play_animaiton** signal for an animation named: "
            + anim_name
            + "\nand if the animation player should await it's finishing ("
            + str(await_finished)
            + ")"
        ),
        CustomLogger.LEVEL.MILD
    )
    VNSignalBus.play_animation.emit(anim_name, await_finished)


## Covers the screen.
func fade_to_black() -> void:
    UIDirector.cover_screen()


## Reveals the screen.
func reveal_screen() -> void:
    UIDirector.reveal_screen()


## Requests the story event identified by the supplied ID.
func start_event(event_id) -> void:
    var event: GameEvent = SystemAdministrators.find_event_by_id(event_id)
    VNSignalBus.event_found.emit(event)


## Reveals the scene through the UI director.
func display_scene() -> void:
    if UIDirector.fade_flag_operator.modulate.a > 0.1:
        UIDirector.fade_flag_hide()

    if UIDirector.cover_operator.modulate.a > 0.1:
        await get_tree().create_timer(0.5).timeout
        UIDirector.reveal_screen()
