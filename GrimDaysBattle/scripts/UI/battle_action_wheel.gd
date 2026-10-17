extends Control
## Authored wheel bound to one production actor and one input turn.
class_name BattleActionWheel

const RESOURCE_ICONS = {
    CombatStats.STATS.Mana: preload("res://GrimDays/assets/visuals/ui/gui/stat_icons/mana.webp"),
    CombatStats.STATS.Energy: preload("res://GrimDays/assets/visuals/ui/gui/stat_icons/energy.webp"),
}

var flow: BattleEncounterFlow
var actor: BattleUnit
var input_turn: int = -1
var _generation: int = 0
var _accepting: bool = false
var _closing: bool = false
var _mode: String = ""
@onready var panel: Panel = %"Skill Selection Panel"
@onready var skill_template: Button = %"Skill Button Template"
@onready var skills: Control = skill_template.get_parent()
@onready var scroll: Control = skills.get_parent()
@onready var items: GridContainer = %"Item Grid"
@onready var animator: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
    hide()
    panel.hide()
    panel.modulate.a = 1.0
    panel.pivot_offset_ratio = Vector2.ZERO
    panel.pivot_offset = Vector2.ZERO
    panel.scale = Vector2(2.0, 2.0)
    z_index = 50
    skill_template.hide()
    %Defend.tooltip_text = "Defend: up to +35 Physical and Magical Resistance until round end (cap 90)."
    %Wait.tooltip_text = "Wait: act last this round. Once per round."
    %Items.tooltip_text = "Items"
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var clockwise: Array[Button] = [%Attack, %Skills, %Items, %Defend, %Wait]
    for index in clockwise.size():
        clockwise[index].focus_next = clockwise[index].get_path_to(clockwise[(index + 1) % clockwise.size()])
        clockwise[index].focus_previous = clockwise[index].get_path_to(clockwise[(index - 1) % clockwise.size()])
    %Attack.pressed.connect(func(): _choose(actor.get_basic_action()))
    %Special.pressed.connect(func(): _choose(actor.template_resource.special_action))
    %Skills.pressed.connect(func(): _show_panel("skills"))
    %Items.pressed.connect(func(): _show_panel("items"))
    %Defend.pressed.connect(func(): _command(CombatActions.COMMAND.DEFEND))
    %Wait.pressed.connect(func(): _command(CombatActions.COMMAND.WAIT))
    # Decorative children must never swallow button clicks.
    for control in find_children("*", "Control", true, false):
        if control is TextureRect or control is ColorRect or control is Label:
            control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func open(menu_flow: BattleEncounterFlow, unit: BattleUnit, turn: int) -> void:
    _generation += 1
    flow = menu_flow
    actor = unit
    input_turn = turn
    var generation := _generation
    _accepting = false
    _closing = false
    mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
    _mode = ""
    panel.hide()
    show()
    animator.play("appear")
    _refresh_buttons()
    while animator.is_playing() and generation == _generation:
        await get_tree().process_frame
    if generation != _generation:
        return
    _accepting = true
    mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED
    _refresh_buttons()
    %Attack.grab_focus()


func close() -> void:
    if not visible or _closing:
        return
    _closing = true
    _accepting = false
    mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
    _generation += 1
    var generation := _generation
    panel.hide()
    _refresh_buttons()
    animator.play_backwards("appear")
    while animator.is_playing() and generation == _generation:
        await get_tree().process_frame
    if generation == _generation:
        hide()
        _closing = false


func wait_until_hidden(continuation: Callable) -> void:
    close()
    while visible and continuation.call():
        await get_tree().process_frame


func _process(_delta: float) -> void:
    if _accepting:
        _refresh_buttons()


func _is_current() -> bool:
    return (
        _accepting
        and is_instance_valid(flow)
        and flow.turn_id == input_turn
        and flow.active_unit == actor
        and flow.state == BattleEncounterFlow.STATE.ACTION
    )


func _refresh_buttons() -> void:
    var current := _is_current()
    %Attack.disabled = not current or not actor.can_use_action(actor.get_basic_action(), true)
    %Special.visible = is_instance_valid(actor) and actor.template_resource.special_action != null
    %Special.disabled = not current or not actor.can_use_action(actor.template_resource.special_action, true)
    %Defend.disabled = not current or not flow.can_choose_command(CombatActions.COMMAND.DEFEND)
    %Wait.disabled = not current or not flow.can_choose_command(CombatActions.COMMAND.WAIT)
    %Skills.disabled = not current
    %Items.disabled = not current
    for button in skills.get_children() + items.get_children():
        if button is Button and button.has_meta(&"action_choice"):
            var reason := (
                actor.get_action_unavailable_reason(button.get_meta(&"action_choice"), true) if current else ""
            )
            button.disabled = not current or not reason.is_empty()
            button.tooltip_text = button.get_meta(&"description", "")
            if not reason.is_empty():
                button.tooltip_text += "\n" + reason
        elif button is Button and button.has_meta(&"item_choices"):
            var choices: Array = button.get_meta(&"item_choices")
            button.disabled = not current or not choices.any(func(choice): return actor.can_use_action(choice, true))


func _choose(action: ActionTemplate) -> void:
    if _is_current() and action and flow.choose_action(input_turn, action):
        close()


func _command(command: int) -> void:
    if _is_current() and flow.choose_command(input_turn, command):
        close()


func _show_panel(mode: String) -> void:
    if not _is_current():
        return
    if _mode == mode and panel.visible:
        panel.hide()
        return
    _mode = mode
    panel.show()
    scroll.visible = mode == "skills"
    items.visible = mode == "items"
    if mode == "skills":
        _build_skills()
    else:
        _build_items()
    var holder: Control = skills if mode == "skills" else items
    for child in holder.get_children():
        if child is Button and child.visible and not child.disabled:
            child.grab_focus()
            break


func _build_skills() -> void:
    for child in skills.get_children():
        if child != skill_template:
            child.free()
    for action in actor.get_owned_actions():
        if action == actor.get_basic_action() or action == actor.template_resource.special_action:
            continue
        var button := skill_template.duplicate() as Button
        skills.add_child(button)
        button.show()
        var row := button.get_child(0)
        row.get_node("Skill Icon").texture = action.icon
        row.get_node("Skill Name").text = action.display_name
        row.get_node("Cost Type Icon").hide()
        row.get_node("Skill Cost").hide()
        var cost_holder := HBoxContainer.new()
        cost_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_child(cost_holder)
        var rank := action.get_rank_template(actor.get_action_rank(action))
        if rank:
            for stat_id in rank.cost:
                var label := Label.new()
                label.text = str(rank.cost[stat_id])
                label.add_theme_font_size_override("font_size", 22)
                label.mouse_filter = Control.MOUSE_FILTER_IGNORE
                cost_holder.add_child(label)
                if RESOURCE_ICONS.has(stat_id):
                    var icon := TextureRect.new()
                    icon.texture = RESOURCE_ICONS[stat_id]
                    icon.custom_minimum_size = Vector2(24, 24)
                    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
                    cost_holder.add_child(icon)
                else:
                    var resource_name := Label.new()
                    resource_name.text = CombatStats.get_stat_as_string(stat_id)
                    resource_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
                    cost_holder.add_child(resource_name)
        button.tooltip_text = action.description
        if button.tooltip_text.is_empty() and rank and rank.effects:
            for effect in rank.effects.all:
                if effect and not effect.description.is_empty():
                    button.tooltip_text += effect.get_description() + "\n"
        if button.tooltip_text.is_empty():
            button.tooltip_text = action.display_name
        button.custom_minimum_size.x = maxf(380.0, row.get_combined_minimum_size().x)
        for control in button.find_children("*", "Control", true, false):
            control.mouse_filter = Control.MOUSE_FILTER_IGNORE
        button.set_meta(&"action_choice", action)
        button.set_meta(&"description", button.tooltip_text)
        var reason := actor.get_action_unavailable_reason(action, true)
        button.disabled = not reason.is_empty()
        if button.disabled:
            button.tooltip_text += "\n" + reason
        button.pressed.connect(_choose.bind(action))


func _build_items() -> void:
    for child in items.get_children():
        items.remove_child(child)
        child.queue_free()
    var available := BattleItemAction.available(actor)
    for index in 9:
        var slot := index + 1
        var stack: ItemBase = actor.inventory.slots.get(slot) if actor.inventory else null
        var choices: Array[ActionTemplate] = []
        for action: BattleItemAction in available:
            if action.matches_stack(stack):
                choices.append(action)
        var button := Button.new()
        button.custom_minimum_size = Vector2(120, 120)
        button.expand_icon = true
        button.clip_text = true
        button.add_theme_font_size_override("font_size", 24)
        button.add_theme_constant_override("icon_max_width", 40)
        button.icon = stack.template.icon if stack else null
        button.text = "%s\nx%s" % [stack.template.display_name, stack.count] if stack else "Empty"
        button.tooltip_text = stack.template.description if stack else "Empty slot"
        button.set_meta(&"item_choices", choices)
        button.disabled = not choices.any(func(choice): return actor.can_use_action(choice, true))
        button.pressed.connect(_select_item.bind(choices))
        items.add_child(button)


func _select_item(choices: Array[ActionTemplate]) -> void:
    if not _is_current():
        return
    if choices.size() == 1:
        _choose(choices[0])
        return
    # Preserve each authored target mode for items that offer multiple uses.
    for child in items.get_children():
        items.remove_child(child)
        child.queue_free()
    for action in choices:
        var button := Button.new()
        button.text = action.display_name
        button.set_meta(&"action_choice", action)
        button.disabled = not actor.can_use_action(action, true)
        button.pressed.connect(_choose.bind(action))
        items.add_child(button)


func _unhandled_input(event: InputEvent) -> void:
    if _is_current() and panel.visible and event.is_action_released("back"):
        panel.hide()
        %Skills.grab_focus()
        get_viewport().set_input_as_handled()
