extends NinePatchRect
## Authored skill panel with one unit-wide draft. Only Apply purchases through the party lease.
class_name BattleSkillPreparationView

signal state_changed
signal status_changed(message: String)

const PAYLOAD_PREVIEW = preload("res://GrimDaysBattle/scripts/Skills/UI/skill_payload_preview.gd")
const PAGE_SCENE = preload("res://GrimDaysBattle/scenes/ui/skill_tree/tree_page.tscn")
const PLACEHOLDER = preload("res://GrimDaysBattle/scenes/ui/skill_tree/node_placeholder.tres")

var _party: BattlePartyManager
var _unit: BattleUnit
var _lease_owner: Node
var _revision: int = -1
var _generation: int = 0
var _draft: Dictionary = {}
var _nodes: Dictionary = {}
var _selected_id: StringName
var _hovered_id: StringName
var _fallback_id: StringName
var _info_offsets: Dictionary = {}
var _ledger: BattleSkillInvestment
var _plan: Dictionary = {}
var _layout_errors: PackedStringArray = []
var _message: String = ""
var _balance: String = ""
var _applying: bool = false

@onready var _tabs: TabContainer = $MarginContainer/HBoxContainer/Skills/TreeTabs
@onready var _apply: Button = %"Apply Changes Button"
@onready var _clear: Button = %"Discard Changes Button"
@onready var _icon_margin: MarginContainer = %"Node Icon".get_parent().get_parent()
@onready var _info_scroll: ScrollContainer = $"MarginContainer/HBoxContainer/Node Info Scroll"
@onready var _icon: TextureRect = %"Node Icon"
@onready var _node_name: Label = %"Node Name"
@onready var _description: RichTextLabel = %"Node Description"
@onready var _final: RichTextLabel = %"Node Final Effect"
@onready var _next: RichTextLabel = %"Next Node Investment"


func _ready() -> void:
    _apply.pressed.connect(apply_draft)
    _clear.pressed.connect(clear_draft)
    _tabs.tab_changed.connect(_on_tree_changed)
    # The filled reference remains authored in the scene, but is never a runtime tab.
    dismiss()


func present(party: BattlePartyManager, unit: BattleUnit, lease_owner: Node) -> void:
    dismiss()
    _party = party
    _unit = unit
    _lease_owner = lease_owner
    if not is_instance_valid(_unit) or not _unit.skills:
        _message = "No skills available for this ally."
        _publish_status()
        return
    _revision = _unit.skills.revision
    _unit.skills.changed.connect(_on_unit_changed)
    _message = "One point per rank. Apply confirms all trees."
    _build_pages()
    _render()


## Authored chrome survives unit switches. Only runtime pages and subscriptions are discarded.
func dismiss() -> void:
    _generation += 1
    _disconnect_unit()
    _unit = null
    _party = null
    _lease_owner = null
    _revision = -1
    _draft.clear()
    _nodes.clear()
    _ledger = null
    _plan.clear()
    _layout_errors.clear()
    _message = ""
    _balance = ""
    if is_instance_valid(_tabs):
        _clear_pages()
    _clear_selection()
    if is_instance_valid(_apply):
        _apply.disabled = true
        _clear.disabled = true


func _exit_tree() -> void:
    _generation += 1
    _disconnect_unit()


func _disconnect_unit() -> void:
    if is_instance_valid(_unit) and _unit.skills and _unit.skills.changed.is_connected(_on_unit_changed):
        _unit.skills.changed.disconnect(_on_unit_changed)


func _clear_pages() -> void:
    for child in _tabs.get_children():
        _tabs.remove_child(child)
        child.queue_free()


## New revision means old buttons must become inert, even before queued deletion runs.
func _on_unit_changed() -> void:
    _draft.clear()
    _revision = _unit.skills.revision
    if _applying:
        return
    _generation += 1
    _message = "Unit state updated. Pending investments cleared."
    _build_pages(true)
    _render()
    state_changed.emit()


func _live() -> bool:
    return (
        is_inside_tree()
        and is_instance_valid(_party)
        and is_instance_valid(_unit)
        and is_instance_valid(_lease_owner)
        and _party.owns_unit(_unit)
        and _party.owns_preparation(_lease_owner)
        and _unit.skills != null
        and _unit.skills.revision == _revision
    )


## Disposable ledgers never modify the unit, its grants or shared definitions.
func _preview(draft: Dictionary) -> Dictionary:
    var candidate := BattleSkillInvestment.new()
    var errors := candidate.configure(_unit.template_resource.skill_collection)
    if errors.is_empty():
        errors = candidate.restore(_unit.skills.capture(), _unit.skills.earned_points())
    if errors.is_empty() and not draft.is_empty():
        errors = candidate.purchase(draft, _unit.skills.earned_points(), _unit.skills.stat_values(), candidate.revision)
    return {"ledger": candidate, "errors": errors}


func stage_rank(id: StringName, amount: int) -> bool:
    if not _live() or amount not in [-1, 1] or not _nodes.has(id) or not _layout_errors.is_empty():
        return false
    var proposed := _draft.duplicate()
    var delta: int = proposed.get(id, 0) + amount
    if delta < 0:
        return false
    if delta == 0:
        proposed.erase(id)
    else:
        proposed[id] = delta
    var removed := _remove_pending_dependents(proposed) if amount < 0 else PackedStringArray()
    var preview := _preview(proposed)
    var errors: PackedStringArray = preview.errors
    if errors.is_empty():
        errors = BattleSkillChainResolver.resolve(preview.ledger, _unit.skills.stat_values()).errors
    if not errors.is_empty():
        _message = " ".join(errors)
        _publish_status()
        return false
    _draft = proposed
    if amount > 0:
        _fallback_id = id
        _show_node(id)
    _message = "Pending until Apply."
    if not removed.is_empty():
        _message += " Also removed pending investments: %s." % ", ".join(removed)
    _render()
    return true


## Repeated removal handles any dependency order, rank thresholds and cross-tree prerequisites.
func _remove_pending_dependents(proposed: Dictionary) -> PackedStringArray:
    var removed := PackedStringArray()
    var changed := true
    while changed:
        changed = false
        for id in proposed.keys():
            var node: BattleSkillNode = _nodes[id].definition
            var dependencies := BattleSkillTreeCollection.dependencies(node)
            for prerequisite in dependencies:
                var rank: int = _unit.skills.ledger.get_rank(prerequisite) + proposed.get(prerequisite, 0)
                if rank < dependencies[prerequisite]:
                    proposed.erase(id)
                    removed.append(node.get_display_name())
                    changed = true
                    break
    return removed


func clear_draft() -> void:
    if not _live():
        return
    _draft.clear()
    _message = "Pending investments discarded. Purchased ranks unchanged."
    _render()


func apply_draft() -> void:
    if not _live() or _draft.is_empty() or not _layout_errors.is_empty():
        return
    _applying = true
    var errors := _party.purchase_skills(_unit.template_resource.id, _draft.duplicate(), _revision, _lease_owner)
    _applying = false
    _message = "Purchases applied." if errors.is_empty() else " ".join(errors)
    if errors.is_empty():
        _draft.clear()
        _revision = _unit.skills.revision
    _render()
    state_changed.emit()


func _build_pages(preserve: bool = false) -> void:
    var selected_tree: StringName
    var fallback_node := _fallback_id
    var info_offsets := _info_offsets.duplicate()
    var offsets: Dictionary = {}
    if preserve:
        for page: BattleSkillTreePage in _tabs.get_children():
            offsets[page.tree_id] = Vector2i(page.scroll.scroll_horizontal, page.scroll.scroll_vertical)
            if page.get_index() == _tabs.current_tab:
                selected_tree = page.tree_id
    _clear_pages()
    _nodes.clear()
    _layout_errors.clear()
    var generation := _generation
    for tree in _unit.template_resource.skill_collection.trees:
        var page := PAGE_SCENE.instantiate() as BattleSkillTreePage
        _tabs.add_child(page)
        var title := tree.display_name if not tree.display_name.is_empty() else String(tree.id)
        _tabs.set_tab_title(page.get_index(), title)
        _layout_errors.append_array(page.populate(tree))
        for id in page.nodes:
            var node: BattleSkillNodeView = page.nodes[id]
            _nodes[id] = node
            node.selected.connect(
                func(node_id: StringName):
                    if generation == _generation and _live():
                        _select_node(node_id)
            )
            node.hovered.connect(
                func(node_id: StringName):
                    if generation == _generation and _live():
                        _hovered_id = node_id
                        _show_node(node_id)
            )
            node.hover_ended.connect(
                func(node_id: StringName):
                    if generation == _generation and _hovered_id == node_id:
                        _hovered_id = &""
                        _show_node(_fallback_id)
            )
            node.rank_requested.connect(
                func(node_id: StringName, amount: int):
                    if generation == _generation:
                        stage_rank(node_id, amount)
            )
        if offsets.has(page.tree_id):
            _restore_scroll.call_deferred(page, offsets[page.tree_id], generation)
        if page.tree_id == selected_tree:
            _tabs.current_tab = page.get_index()
    if preserve and _nodes.has(fallback_node):
        _fallback_id = fallback_node
        _info_offsets = info_offsets
        _selected_id = fallback_node


## Ordinary edits refresh in place: no tab switch, focus loss or scroll reset.
func _render() -> void:
    var preview := _preview(_draft)
    _ledger = preview.ledger
    _plan = BattleSkillChainResolver.resolve(_ledger, _unit.skills.stat_values())
    var errors: PackedStringArray = preview.errors.duplicate()
    errors.append_array(_plan.errors)
    errors.append_array(_layout_errors)
    var valid := _live() and errors.is_empty()
    var snapshot := _unit.skills.snapshot()
    var staged := _ledger.spent_points() - int(snapshot.spent)
    _balance = (
        "Skill points: %s available | %s purchased | %s pending (all trees)."
        % [snapshot.available - staged, snapshot.spent, staged]
    )
    _apply.disabled = not valid or _draft.is_empty()
    _clear.disabled = not _live() or _draft.is_empty()
    for id in _nodes:
        var reasons := _ledger.explain_requirements(id, _unit.skills.stat_values())
        var rank := _ledger.get_rank(id)
        var node: BattleSkillNodeView = _nodes[id]
        var can_invest := (
            valid
            and reasons.is_empty()
            and rank < node.definition.maximum_rank
            and _ledger.available_points(_unit.skills.earned_points()) > 0
        )
        node.refresh(
            rank,
            _draft.get(id, 0),
            can_invest,
            valid and _draft.get(id, 0) > 0,
            "Requirements met." if reasons.is_empty() else " ".join(reasons)
        )
    for page: BattleSkillTreePage in _tabs.get_children():
        page.refresh_connections(_ledger)
    _refresh_selection()
    _publish_status(" ".join(errors))


func _publish_status(error: String = "") -> void:
    status_changed.emit((_balance + "\n" + (_message if error.is_empty() else error)).strip_edges())


## Left-click/focus pins the fallback; hover temporarily overrides it.
func _select_node(id: StringName) -> void:
    if not _nodes.has(id):
        return
    _fallback_id = id
    _show_node(id)


func _show_node(id: StringName) -> void:
    if _selected_id != id:
        if not _selected_id.is_empty():
            _info_offsets[_selected_id] = _info_scroll.scroll_vertical
        _selected_id = id
        _info_scroll.scroll_vertical = 0
        _restore_info_scroll.call_deferred(id, _generation)
    _refresh_selection()


func _restore_info_scroll(id: StringName, generation: int) -> void:
    if not is_inside_tree() or generation != _generation:
        return
    await get_tree().process_frame
    if generation == _generation and id == _selected_id and is_instance_valid(_info_scroll):
        _info_scroll.scroll_vertical = _info_offsets.get(id, 0)


func _on_tree_changed(_index: int) -> void:
    _clear_selection()


func _clear_selection() -> void:
    _selected_id = &""
    _hovered_id = &""
    _fallback_id = &""
    _info_offsets.clear()
    if is_instance_valid(_info_scroll):
        _info_scroll.scroll_vertical = 0
    _hide_details()


func _hide_details() -> void:
    for control in [_icon_margin, _icon, _node_name, _description, _final, _next]:
        if is_instance_valid(control):
            control.hide()


func _refresh_selection() -> void:
    if _selected_id.is_empty() or not _nodes.has(_selected_id) or not _ledger:
        _hide_details()
        return
    var node: BattleSkillNode = _nodes[_selected_id].definition
    var rank := _ledger.get_rank(node.id)
    _icon.texture = node.get_display_icon() if node.get_display_icon() else PLACEHOLDER
    _node_name.text = node.get_display_name()
    var reasons := _ledger.explain_requirements(node.id, _unit.skills.stat_values())
    _description.text = node.get_description()
    if not reasons.is_empty():
        _description.text += "\nLocked: " + " ".join(reasons)
    _final.text = PAYLOAD_PREVIEW.final_text(node, _ledger, _unit)
    if rank > 0 and not reasons.is_empty():
        _final.text = "Currently unavailable.\n" + _final.text
    elif rank > 0 and PAYLOAD_PREVIEW.is_suppressed(node, _ledger, _unit.skills.stat_values()):
        _final.text = "Superseded by a later invested node.\n" + _final.text
    _next.text = PAYLOAD_PREVIEW.next_text(node, rank, _unit)
    for control in [_icon_margin, _icon, _node_name, _description, _next]:
        control.show()
    _final.visible = rank > 0


func _restore_scroll(page: BattleSkillTreePage, scroll_position: Vector2i, generation: int) -> void:
    if generation == _generation and is_instance_valid(page):
        page.scroll.scroll_horizontal = scroll_position.x
        page.scroll.scroll_vertical = scroll_position.y
