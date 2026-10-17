# Editor configuration for party_preparation_smoke_suite.
@tool
extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"
## Exercises the real modal and Dialogic Call contract, not just inventory APIs.


class MarkerEvent:
    extends DialogicEvent
    var visits: int = 0

    func _execute() -> void:
        visits += 1


## Checks when preparation can open, its pause/save restrictions, real Dialogic calls, cancellation
## and party controls.
func run() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    var original_state: GameManagerStates.STATES = GameManager.state
    var party: BattlePartyManager = BattleController.party_manager
    var saved: Dictionary = party._get_state()
    assert(not Dialogic.current_timeline)
    var session := UIDirector._get_party_preparation()
    # Replay has an enum value but no production state node yet. Register a
    # temporary state so rejection is tested in Replay, not the previous mode.
    var replay_fixture: GameManagerState
    var states := GameManager.state_manager
    if not states.states.has(GameManagerStates.STATES.ScenarioReplay):
        replay_fixture = GameManagerState.new()
        replay_fixture.id = GameManagerStates.STATES.ScenarioReplay
        states.add_child(replay_fixture)
        states.states[replay_fixture.id] = replay_fixture
    for state in [
        GameManagerStates.STATES.BeforeGame,
        GameManagerStates.STATES.Scenario,
        GameManagerStates.STATES.Battle,
        GameManagerStates.STATES.Loading,
        GameManagerStates.STATES.ScenarioReplay
    ]:
        GameManager.state = state
        assert(GameManager.state == state)
        assert(not UIDirector.show_party_preparation())
        assert(not UIDirector.show_story_party_preparation())
    GameManager.state = GameManagerStates.STATES.Navigation
    if replay_fixture:
        states.states.erase(replay_fixture.id)
        replay_fixture.free()
    assert(party.acquire_encounter(self))
    assert(not UIDirector.show_party_preparation())
    assert(not party.set_active_party([]), "An encounter must freeze roster edits too.")
    party.release_encounter(self)
    assert(UIDirector.show_party_preparation())
    assert(session.active and get_tree().paused)
    assert(not UIDirector.show_party_preparation())
    assert(not party.acquire_encounter(self), "Preparation must exclude concurrent battles.")
    assert(not SaveAndLoadSystemManager.can_save_game())
    assert(party.can_prepare_inventory())
    await _test_controls(session.panel, party)
    var stale: BattlePreparationPanel = session.panel
    session.close()
    assert(not session.active and not get_tree().paused)
    assert(stale.party == null and stale.inventory_view.party == null)
    assert(party.acquire_encounter(self))
    party.release_encounter(self)
    await get_tree().process_frame
    await _test_story(session)
    GameManager.state = GameManagerStates.STATES.Navigation
    assert(UIDirector.show_party_preparation())
    GameManager.state = GameManagerStates.STATES.Loading
    session._process(0.0)
    assert(not session.active and not get_tree().paused)
    GameManager.state = GameManagerStates.STATES.Navigation
    assert(UIDirector.show_party_preparation())
    await SaveAndLoadSystemManager.cancel_story_battles()
    assert(not session.active and not get_tree().paused)
    party.restore(saved)
    GameManager.state = original_state


## Exercises the panel’s roster, inventory, equipment and skill controls using temporary party
## data.
func _test_controls(panel: BattlePreparationPanel, party: BattlePartyManager) -> void:
    assert(panel.scene_file_path == "res://GrimDaysBattle/scenes/ui/party_management.tscn")
    assert(panel.get_node("Character Panel").visible)
    await _click(panel.get_node("Character Pool and Options/Button2"))
    assert(panel.get_node("Skill Panel").visible and not panel.get_node("Character Panel").visible)
    await _click(panel.get_node("Character Pool and Options/Button"))
    assert(panel.get_node("Character Panel").visible)
    var unit: BattleUnit = party.runtime_units[panel.unit_id]
    assert(
        panel.get_node(panel.CHARACTER + "/Character Name/Character Name").text == unit.template_resource.display_name
    )
    var potion := ItemTemplate.new()
    potion.id = &"preparation_potion"
    potion.display_name = "Preparation potion"
    potion.stack_size = 3
    party.stash.clear_items()
    unit.inventory.clear_items()
    assert(party.stash.add_item(ItemBase.create(potion, 3)))
    panel.inventory_view.refresh()
    var inventory := panel.inventory_view
    assert(inventory.stash_slots.get_child_count() == party.stash.size)
    assert(inventory.personal_slots.get_child_count() == unit.inventory.size)
    await _click(inventory.stash_slots.get_child(0).get_node("Select"))
    var stale_command: Callable = inventory._commands.values()[0]
    var stale_command_id: int = inventory.item_actions.get_item_id(0)
    _choose(inventory, "To unit (1)")
    assert(unit.inventory.slots[1].count == 1 and party.stash.slots[1].count == 2)
    stale_command.call()
    assert(unit.inventory.slots[1].count == 1, "An old rendering cannot spend another stack.")
    inventory.stash_slots.get_child(0).get_node("Select").pressed.emit()
    inventory.item_actions.id_pressed.emit(stale_command_id)
    assert(unit.inventory.slots[1].count == 1, "Old menu IDs must not execute a newly opened menu command.")
    _choose(inventory, "To unit (all)")
    assert(unit.inventory.slots[1].count == 3 and party.stash.slots[1] == null)
    var gear := EquipmentTemplate.new()
    gear.id = &"preparation_gear"
    gear.display_name = "Preparation gear"
    gear.equips_to.assign([UnitEquipmentSlot.SLOT.RightHand])
    gear.weight = 3.0
    assert(unit.inventory.add_item(ItemBase.create(gear)))
    panel.inventory_view.refresh()
    inventory.personal_slots.get_child(1).get_node("Select").pressed.emit()
    _choose(inventory, "Equip: Right_Hand")
    assert(unit.get_equipment_slot(UnitEquipmentSlot.SLOT.RightHand).equipped.template == gear)
    assert(panel._project_skills != null, "Preparation uses the replacement investment UI.")
    var roster_check := panel.roster.get_child(0).get_node("Active") as CheckBox
    roster_check.toggled.emit(false)
    assert(not party.active_party_ids.is_empty(), "The screen must not accidentally leave an empty party.")
    # Equipment buttons return gear to personal storage through the same service.
    panel.get_node("Character Pool and Options/Button").pressed.emit()
    await _click(panel.get_node(panel.EQUIPMENT + "/Character Silouhette/Right Hand Slot/Select"))
    _choose(inventory, "Unequip")
    assert(unit.get_equipment_slot(UnitEquipmentSlot.SLOT.RightHand).equipped == null)
    # A different runtime ally must update all views and invalidate open commands.
    var template := CELINE_TEMPLATE.duplicate() as BattleUnitTemplate
    template.id = &"preparation_reserve"
    template.display_name = "Preparation reserve"
    var reserve := BattleUnit.create(template, false)
    party.add_child(reserve)
    party.runtime_units[template.id] = reserve
    panel._refresh_roster()
    panel.roster.get_child(1).get_node("Active").toggled.emit(true)
    assert(template.id in party.active_party_ids)
    panel.roster.get_child(1).get_node("Up").pressed.emit()
    assert(party.active_party_ids[0] == template.id)
    panel.roster.get_child(0).get_node("Select").pressed.emit()
    assert(panel.unit_id == template.id and inventory.unit_id == template.id)
    assert(panel.get_node(panel.CHARACTER + "/Character Name/Character Name").text == template.display_name)
    stale_command.call()
    assert(reserve.inventory.slots[1] == null)
    await get_tree().process_frame


## Execute the actual addon Call event. Done advances once; replacement and load
## cancellation must not leave a paused addon coroutine advancing a new timeline.
func _test_story(session: BattlePreparationSession) -> void:
    GameManager.state = GameManagerStates.STATES.Scenario
    var marker := await _start_call()
    assert(session.active and Dialogic.paused and marker.visits == 0)
    assert(not UIDirector.show_party_preparation())
    session.close()
    session.close()
    await get_tree().process_frame
    assert(marker.visits == 1 and not Dialogic.paused and not get_tree().paused)
    await Dialogic.clear()
    marker = await _start_call()
    var replacement := DialogicTimeline.new()
    var replacement_marker := MarkerEvent.new()
    replacement_marker.event_node_ready = true
    replacement.events = [replacement_marker]
    replacement.events_processed = true
    Dialogic.start_timeline(replacement)
    await get_tree().process_frame
    assert(not session.active and not Dialogic.paused and marker.visits == 0)
    assert(replacement_marker.visits == 1, "Replacing a timeline must not inherit our pause.")
    await Dialogic.clear()
    marker = await _start_call()
    assert(session.active)
    session.close()
    # Replace the timeline before deferred continuation is allowed to run.
    await Dialogic.clear()
    Dialogic.current_timeline = DialogicTimeline.new()
    await get_tree().process_frame
    assert(marker.visits == 0)
    await Dialogic.clear()
    marker = await _start_call()
    await SaveAndLoadSystemManager.cancel_story_battles()
    await get_tree().process_frame
    assert(marker.visits == 0 and not session.active and not Dialogic.paused)
    await Dialogic.clear()


## Starts a test timeline containing the real preparation call and returns its marker event for
## continuation checks.
func _start_call() -> MarkerEvent:
    var event := DialogicCallEvent.new()
    event.autoload_name = "UIDirector"
    event.method = "show_story_party_preparation"
    event.event_node_ready = true
    var marker := MarkerEvent.new()
    marker.event_node_ready = true
    Dialogic.current_timeline = DialogicTimeline.new()
    Dialogic.current_timeline_events = [event, marker]
    Dialogic.current_event_idx = -1
    Dialogic.handle_event(0)
    await get_tree().process_frame
    return marker


## Sends a mouse-button press and release to a control so the test uses its input path.
func _click(button: Control) -> void:
    await get_tree().process_frame
    var position := button.get_global_transform_with_canvas() * (button.size * 0.5)
    var motion := InputEventMouseMotion.new()
    motion.position = position
    get_viewport().push_input(motion, true)
    for pressed in [true, false]:
        var click := InputEventMouseButton.new()
        click.button_index = MOUSE_BUTTON_LEFT
        click.pressed = pressed
        click.position = position
        get_viewport().push_input(click, true)
    await get_tree().process_frame


## Selects a popup item by its displayed title.
func _choose(inventory: BattlePreparationInventory, title: String) -> void:
    for index in inventory.item_actions.item_count:
        if inventory.item_actions.get_item_text(index) == title:
            inventory.item_actions.id_pressed.emit(inventory.item_actions.get_item_id(index))
            return
    assert(false, "Missing inventory command: " + title)


## Finds a button with the requested label under the supplied node.
func _button(parent: Node, label: String) -> Button:
    for child in parent.get_children():
        if child is Button and child.text == label:
            return child
        var found := _button(child, label)
        if found:
            return found
    return null
