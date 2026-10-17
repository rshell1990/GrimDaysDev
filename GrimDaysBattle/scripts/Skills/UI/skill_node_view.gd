extends Control
## Scene-owned node controls. Requests carry the snapshot token that created this node.
class_name BattleSkillNodeView

signal selected(id: StringName)
signal hovered(id: StringName)
signal hover_ended(id: StringName)
signal rank_requested(id: StringName, amount: int)

const PLACEHOLDER = preload("res://GrimDaysBattle/scenes/ui/skill_tree/node_placeholder.tres")

var definition: BattleSkillNode
@onready var icon: TextureRect = %"Node Icon"
@onready var current_rank: Label = %"Current Rank"
@onready var max_rank: Label = %"Max Rank"
@onready var invest: Button = %Invest
@onready var refund: Button = %Refund


func _ready() -> void:
    mouse_entered.connect(_hover)
    mouse_exited.connect(_check_hover_exit.call_deferred)
    for button in [invest, refund]:
        button.mouse_entered.connect(_hover)
        button.mouse_exited.connect(_check_hover_exit.call_deferred)
        button.gui_input.connect(_gui_input)
        button.focus_entered.connect(_select)
    invest.pressed.connect(_request_rank.bind(1))
    refund.pressed.connect(_request_rank.bind(-1))


func _select() -> void:
    if definition:
        selected.emit(definition.id)


func configure(node: BattleSkillNode) -> void:
    definition = node
    icon.texture = node.get_display_icon() if node.get_display_icon() else PLACEHOLDER
    max_rank.text = str(node.maximum_rank)
    for button in [invest, refund]:
        button.set_meta(&"skill_node_id", node.id)
    invest.set_meta(&"draft_delta", 1)
    refund.set_meta(&"draft_delta", -1)


## Rank and button updates retain the same input targets and scene geometry.
func refresh(rank: int, pending: int, can_invest: bool, can_refund: bool, reasons: String) -> void:
    current_rank.text = str(rank)
    current_rank.modulate = Color(1.0, 0.8, 0.45) if pending > 0 else Color.WHITE
    tooltip_text = (
        "%s\n%s committed; %s pending.\n%s" % [definition.get_display_name(), rank - pending, pending, reasons]
    )
    invest.tooltip_text = "Invest one point.\n" + reasons
    refund.tooltip_text = "Undo one pending rank, including dependent pending investments."
    invest.disabled = not can_invest
    refund.disabled = not can_refund


func _request_rank(amount: int) -> void:
    if definition:
        rank_requested.emit(definition.id, amount)


## A click pins details independently of investment. Buttons also forward their click here.
func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        _select()


func _hover() -> void:
    if definition:
        hovered.emit(definition.id)


## Moving between a node and its buttons must not briefly restore another node's details.
func _check_hover_exit() -> void:
    if not is_inside_tree() or not definition:
        return
    var control := get_viewport().gui_get_hovered_control()
    if control != self and (not control or not is_ancestor_of(control)):
        hover_ended.emit(definition.id)
