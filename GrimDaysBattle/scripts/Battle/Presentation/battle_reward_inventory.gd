extends PanelContainer
## Shared-stash overflow choice UI. It requests changes but never grants rewards
## or owns foe cleanup. Old buttons are generation/attempt guarded.
class_name BattleRewardInventory

## Requests disposal of a stored stack quantity for the displayed encounter token.
signal discard_stored(attempt: int, item: ItemBase, amount: int)
## Requests declining an offered reward quantity for the displayed encounter token.
signal decline_reward(attempt: int, index: int, amount: int)
## Requests another settlement attempt after inventory choices.
signal collect_requested(attempt: int)

## Invalidates controls from previous reward-selection renders.
var _generation: int
## Label explaining capacity and pending settlement.
var _status: Label
## Container of shared-inventory rows that can be discarded to make room.
var _stored: VBoxContainer
## Container of pending-loot rows that can be declined.
var _offered: VBoxContainer
## Button requesting collection of the remaining rewards.
var collect: Button


## Builds the stored-item and incoming-reward columns, status text and collection button.
func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    offset_left = 160
    offset_top = 100
    offset_right = -160
    offset_bottom = -100
    add_theme_font_size_override("font_size", 24)
    var content := VBoxContainer.new()
    content.name = "Content"
    add_child(content)
    _status = Label.new()
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(_status)
    var columns := HBoxContainer.new()
    columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(columns)
    _stored = _column(columns, "Shared inventory — discard to make room")
    _offered = _column(columns, "Victory loot — choose what to keep")
    collect = Button.new()
    collect.text = "Collect rewards"
    content.add_child(collect)
    hide()


## Rebuild with fresh item references and discard quantities, invalidating queued
## clicks before old controls leave the tree at the end of this frame.
func present(stash: Inventory, result: BattleResult, attempt: int) -> void:
    _generation += 1
    var generation := _generation
    for rows in [_stored, _offered]:
        for child in rows.get_children():
            rows.remove_child(child)
            child.queue_free()
    for connection in collect.pressed.get_connections():
        collect.pressed.disconnect(connection.callable)
    collect.pressed.connect(
        func():
            if visible and generation == _generation:
                collect_requested.emit(attempt)
    )
    _status.text = (
        "Victory rewards need space. Discarding stored items is permanent. Nothing is awarded until collection succeeds.\nShared inventory capacity: %s slots" # lint:ignore line-length -- Preserve resource path or authored text.
        % stash.size
    )
    for slot in range(1, stash.size + 1):
        var item: ItemBase = stash.slots.get(slot)
        if not item:
            continue
        _row(
            _stored,
            item.template.display_name,
            item.count,
            "Discard",
            func(amount: int):
                if visible and generation == _generation:
                    discard_stored.emit(attempt, item, amount)
        )
    for index in result.reward_offer.size():
        var record: Dictionary = result.reward_offer[index]
        var remaining: int = record.count - result.discarded_rewards.get(index, 0)
        if remaining <= 0:
            continue
        var definition := Inventory.resolve_definition(StringName(record.template_id), record.get("resource_path", ""))
        var label: String = definition.display_name if definition else String(record.template_id)
        _row(
            _offered,
            label,
            remaining,
            "Leave",
            func(amount: int):
                if visible and generation == _generation:
                    decline_reward.emit(attempt, index, amount)
        )
    show()
    collect.grab_focus()


## Adds a titled, scrollable list to the supplied parent and returns its row container.
func _column(parent: Control, title: String) -> VBoxContainer:
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(column)
    var label := Label.new()
    label.text = title
    column.add_child(label)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    column.add_child(scroll)
    var rows := VBoxContainer.new()
    rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(rows)
    return rows


## Adds an item row with buttons for choosing one item or the whole available amount.
func _row(parent: Control, title: String, count: int, verb: String, request: Callable) -> void:
    var row := VBoxContainer.new()
    parent.add_child(row)
    var label := Label.new()
    label.text = "%s ×%s" % [title, count]
    row.add_child(label)
    var buttons := HBoxContainer.new()
    row.add_child(buttons)
    for amount in [1, count] if count > 1 else [1]:
        var button := Button.new()
        button.text = "%s %s" % [verb, "stack" if amount > 1 else "1"]
        button.pressed.connect(request.bind(amount))
        buttons.add_child(button)
