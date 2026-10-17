# Player-driven basement encounter checks using the authored nun battle and aftermath.
extends Control

const TIMELINE = preload("res://editor_only_debug/scenes/battle/basement_story_playtest.dtl")
const STORY_EVENT = preload("res://GrimDaysVN/resources/events/2_0090_in_the_basement_before_battle.tres")

var _started: bool = false


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.05, 0.07, 0.1)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 20)
    center.add_child(content)
    var title := Label.new()
    title.text = "Basement story playtest"
    title.add_theme_font_size_override("font_size", 36)
    content.add_child(title)
    var help := Label.new()
    help.text = (
        "Choose Celine's level, allocate points, then fight the three level-5 sisters.\n"
        + "Victory and defeat continue to the authored aftermath.\n"
        + "Each variant starts a fresh test party. Restart this scene to choose again."
    )
    content.add_child(help)
    for level in [5, 7]:
        var button := Button.new()
        button.text = "Level %s Celine vs the three sisters" % level
        button.custom_minimum_size.y = 64
        button.pressed.connect(_start.bind(level))
        content.add_child(button)
    await get_tree().process_frame
    content.get_child(2).grab_focus()


func start_scene() -> void:
    UIDirector.reveal_screen()
    UIDirector.fade_flag_hide()


## Reset only this debug run's party so the two variants have reproducible starting levels.
func _prepare_party(level: int) -> bool:
    if level not in [5, 7]:
        return false
    var party: BattlePartyManager = BattleController.party_manager
    if not is_instance_valid(party) or not party.can_prepare_inventory():
        return false
    party.reset()
    if not party.ensure_minimum_level(&"CelineTeen", level):
        return false
    return party.set_active_party([&"CelineTeen"])


func _start(level: int) -> void:
    if _started or not _prepare_party(level):
        return
    _started = true
    SceneManager.active_node = self
    GameManager.change_state(GameManagerStates.STATES.Scenario)
    SystemAdministrators.set_location(&"NovarasOrphanageCellar")
    GameManager.current_event = STORY_EVENT
    hide()
    Dialogic.start(TIMELINE)
