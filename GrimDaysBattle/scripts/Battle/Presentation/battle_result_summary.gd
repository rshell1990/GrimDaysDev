extends PanelContainer
## Presents settled value snapshots, never live foes. Only the encounter session
## handles Continue; this view cannot repeat rewards or advance story events.
class_name BattleResultSummary

## Emitted with the encounter token when the player accepts the displayed result.
signal continue_requested(attempt: int)

## Label showing the terminal result heading.
var heading: Label
## Plain-text rich label showing rewards and result details.
var details: RichTextLabel
## Button confirming the result and requesting story continuation.
var continue_button: Button
## Invalidates callbacks from previously presented results.
var _generation: int


## Builds the heading, result text and Continue button, then hides the panel until a result is
## supplied.
func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    offset_left = 240
    offset_top = 120
    offset_right = -240
    offset_bottom = -120
    var content := VBoxContainer.new()
    add_child(content)
    heading = Label.new()
    heading.add_theme_font_size_override("font_size", 40)
    content.add_child(heading)
    details = RichTextLabel.new()
    details.add_theme_font_size_override("normal_font_size", 26)
    details.size_flags_vertical = Control.SIZE_EXPAND_FILL
    details.bbcode_enabled = false
    content.add_child(details)
    continue_button = Button.new()
    continue_button.text = "Continue"
    continue_button.custom_minimum_size.y = 64
    content.add_child(continue_button)
    hide()


## Render the final receipt and recovered party state. Generation and one-shot
## button disabling reject queued clicks from a prior presentation of this view.
func present(result: BattleResult, attempt: int) -> void:
    _generation += 1
    var generation := _generation
    heading.text = "Victory" if result.is_victory() else "Defeat"
    var lines: PackedStringArray = ["Turns: %s   Rounds: %s" % [result.turns, result.rounds], "", "Rewards"]
    if result.is_victory():
        lines.append(
            "Experience: %s for each deployed party member" % result.reward_receipt.get("experience_per_member", 0)
        )
        var items: Array = result.reward_receipt.get("items", [])
        if items.is_empty():
            lines.append("No items collected.")
        for item: Dictionary in items:
            var label: String = item.get("display_name", "")
            lines.append("%s ×%s" % [label if not label.is_empty() else String(item.template_id), item.count])
    else:
        lines.append("No rewards granted.")
    var declined: int = 0
    for amount: int in result.discarded_rewards.values():
        declined += amount
    if declined > 0:
        lines.append("Left behind: %s item(s)" % declined)
    lines.append_array(["", "Party after battle"])
    for member: Dictionary in result.recovered_party_snapshots:
        var values: PackedStringArray = ["Health %s/%s" % [floori(member.health), floori(member.max_health)]]
        for pool in ["mana", "energy", "lucidity"]:
            if member.has(pool):
                values.append("%s %s" % [pool.capitalize(), floori(member[pool])])
        lines.append("%s — %s" % [member.get("display_name", member.id), "; ".join(values)])
    details.text = "\n".join(lines)
    details.scroll_to_line(0)
    for connection in continue_button.pressed.get_connections():
        continue_button.pressed.disconnect(connection.callable)
    continue_button.disabled = false
    continue_button.pressed.connect(
        func():
            if visible and not continue_button.disabled and generation == _generation:
                continue_button.disabled = true
                continue_requested.emit(attempt)
    )
    show()
    continue_button.grab_focus()
