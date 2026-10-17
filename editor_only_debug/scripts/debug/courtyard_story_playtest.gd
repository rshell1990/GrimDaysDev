extends Control
## F6 entry for player-driven placeholder encounter QA. Uses authored events and
## the ordinary runtime party and pre-encounter level milestone; no test-only stat
## overrides, automatic point allocations or automated turns.
## Production story reaches these same handoffs through the ordered story chain.

const SOLO := preload("res://GrimDaysVN/resources/events/2_0025_chores_choice.tres")
## Authored raider prelude for the Harlok-and-goons placeholder.
const GROUP := preload("res://GrimDaysVN/resources/events/2_0032_party_fights_raiders_and_cave_troll.tres")
## Prevents duplicate launcher clicks from starting multiple timelines.
var _started: bool = false


## Builds the two launch buttons for solo Harlok and Harlok with both goons.
func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var background := ColorRect.new()
    background.color = Color(0.05, 0.07, 0.1)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 20)
    center.add_child(content)
    var title := Label.new()
    title.text = "Placeholder encounter playtest"
    title.add_theme_font_size_override("font_size", 36)
    content.add_child(title)
    var help := Label.new()
    help.text = "Choose an encounter, read its prelude, allocate level-3 points, then fight.\nDefeat retries; victory → summary → Continue → next story scene.\nRestart this scene to choose again." # lint:ignore line-length -- Preserve authored text.
    content.add_child(help)
    for choice in [
        {"label": "Demorai placeholder: Harlok", "event": SOLO},
        {"label": "Raider/troll placeholder: Harlok and goons", "event": GROUP}
    ]:
        var button := Button.new()
        button.text = choice.label
        button.custom_minimum_size.y = 64
        button.pressed.connect(_start.bind(choice.event))
        content.add_child(button)
    await get_tree().process_frame
    content.get_child(2).grab_focus()


func start_scene() -> void:
    UIDirector.reveal_screen()
    UIDirector.fade_flag_hide()


## This launcher is replaced by BattleStorySession like any ended VN scene.
func _start(event: GameEventSequence) -> void:
    if _started:
        return
    # This shortcut skips the earlier dialogue, not its progression. Reuse the
    # exact story milestone; the player still distributes every discretionary point.
    if not BattleController.party_manager.ensure_minimum_level(&"CelineTeen", 3):
        CustomLogger.error(
            self, _start, "The encounter playtest requires Celine's level-3 milestone.", CustomLogger.LEVEL.IMPORTANT
        )
        return
    _started = true
    SceneManager.active_node = self
    GameManager.change_state(GameManagerStates.STATES.Scenario)
    hide()
    VNSignalBus.event_found.emit(event)
