extends Control
## Connects authored HUDs to the local encounter without global debug signals.
class_name BattleProductionHUD

const PARTY_CARD = preload("res://GrimDaysBattle/scenes/ui/battle/ally_portrait.tscn")
@export var flow: BattleEncounterFlow
@onready var active: Control = $ActiveAlly
@onready var party: Control = $PartyStatus
@onready var order: Control = $TurnOrder
@onready var round_display: Panel = get_node_or_null("RoundStart") as Panel
var _cards: Dictionary = {}
var _wheel: BattleActionWheel
var _actor: BattleUnit
var _bound: bool = false
var _last_order: Array[BattleUnit] = []
var _last_order_round: int = -1


func _ready() -> void:
    active.hide()
    party.hide()
    order.hide()
    if round_display:
        round_display.hide()
    party.template.hide()
    for control in active.find_children("*", "Control", true, false):
        if control is not BaseButton:
            control.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for control in party.find_children("*", "Control", true, false):
        control.mouse_filter = Control.MOUSE_FILTER_IGNORE
    active.get_node("Flee").pressed.connect(func(): flow.choose_command(flow.turn_id, CombatActions.COMMAND.FLEE))
    if round_display:
        flow.round_presentation = round_display.present_round
    flow.action_presentation = _wait_for_wheel
    flow.action_required.connect(_on_action_required)
    flow.state_changed.connect(_refresh)
    var coordinator: BattleCoordinator = flow.get_parent().get_node("Coordinator")
    coordinator.battle_started.connect(_on_started)
    coordinator.battle_clearing.connect(_on_clearing)
    coordinator.turn_order.changed.connect(_refresh_order)


func _on_started(_token: int) -> void:
    _clear()
    _bound = true
    var coordinator: BattleCoordinator = flow.get_parent().get_node("Coordinator")
    for unit in coordinator.roster.get_allies():
        var card := PARTY_CARD.instantiate() as AllyUnitUI
        party.template.get_parent().add_child(card)
        card.setup(unit)
        _cards[unit] = card


func _on_action_required(turn: int, unit: BattleUnit, _actions: Array[ActionTemplate]) -> void:
    if _wheel and is_instance_valid(_wheel):
        _wheel.close()
    _actor = unit
    active.template.setup(unit)
    var display := flow.stage.get_unit_display(unit)
    _wheel = display.get_node_or_null("UI Elements/Action Wheel") as BattleActionWheel
    if _wheel:
        _wheel.open(flow, unit, turn)
    _refresh()


func _refresh() -> void:
    var choosing := flow.state in [BattleEncounterFlow.STATE.ACTION, BattleEncounterFlow.STATE.TARGETS]
    active.visible = choosing
    party.visible = choosing
    if flow.state != BattleEncounterFlow.STATE.ACTION and is_instance_valid(_wheel):
        _wheel.close()
    if flow.state == BattleEncounterFlow.STATE.STOPPED:
        active.template.setup(null)
        order.hide()
    for unit in _cards:
        _cards[unit].visible = unit != flow.active_unit
    _refresh_order()


func _process(_delta: float) -> void:
    _refresh_order()
    if active.visible:
        active.get_node("Flee").disabled = not flow.can_choose_command(CombatActions.COMMAND.FLEE)


func _refresh_order() -> void:
    if not _bound:
        return
    var coordinator: BattleCoordinator = flow.get_parent().get_node("Coordinator")
    order.visible = coordinator.state == BattleCoordinator.STATE.ACTIVE
    var units := coordinator.turn_order.get_units().filter(
        func(unit): return is_instance_valid(unit) and unit.is_active and coordinator.roster.is_present(unit)
    )
    if units != _last_order or _last_order_round != coordinator.turn_order.round_revision:
        _last_order.assign(units)
        _last_order_round = coordinator.turn_order.round_revision
        order.show_order(_last_order, _last_order_round)


func _on_clearing(_token: int) -> void:
    _clear()


func _clear() -> void:
    _bound = false
    _last_order.clear()
    _last_order_round = -1
    order.show_order(_last_order)
    active.template.setup(null)
    for card in _cards.values():
        card.unbind()
        card.queue_free()
    _cards.clear()
    _actor = null
    _wheel = null
    active.hide()
    party.hide()
    order.hide()
    if round_display:
        round_display.hide()


func _wait_for_wheel(continuation: Callable) -> void:
    if is_instance_valid(_wheel):
        await _wheel.wait_until_hidden(continuation)
