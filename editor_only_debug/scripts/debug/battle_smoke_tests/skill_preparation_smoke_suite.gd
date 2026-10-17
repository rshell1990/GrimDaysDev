extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/unit_skills_smoke_suite.gd"
## Authored preparation panel, pending ranks and read-only previews. No template/save-file mutation.

const PANEL := preload("res://GrimDaysBattle/scenes/ui/party_management.tscn")


## Exercises production draft controls across two trees, atomic Apply, Clear, gate changes, stale
## buttons and preparation-lease rejection.
func run() -> void:
    var fixture := _fixture()
    fixture.collection.trees[0].tiers[0].nodes[0].description = "Scrollable fixture description.\n".repeat(40)
    var template := CELINE_TEMPLATE.duplicate() as BattleUnitTemplate
    template.skill_collection = fixture.collection
    template.level = 4
    # A second tree confirms the draft spends one unit pool, not a per-tab pool.
    var other_tree := BattleSkillTree.new()
    other_tree.id = &"other_tree"
    other_tree.tiers = [BattleSkillTier.new()]
    var other_node := BattleSkillActionNode.new()
    other_node.id = &"other_action"
    other_node.action = _action(other_node.id, 1, 0)
    other_tree.tiers[0].nodes = [other_node]
    fixture.collection.trees.append(other_tree)
    var empty_tier := BattleSkillTier.new()
    empty_tier.column = 5
    other_tree.tiers.append(empty_tier)
    var party := TestParty.new()
    add_child(party)
    var unit := BattleUnit.create(template)
    party.add_child(unit)
    party.runtime_units[template.id] = unit
    unit.get_stat(CombatStats.STATS.Sanity).set_base(10)
    var lease_owner := Node.new()
    add_child(lease_owner)
    assert(party.acquire_preparation(lease_owner))
    var panel := PANEL.instantiate() as BattlePreparationPanel
    add_child(panel)
    panel.present(party, lease_owner)
    panel._show_talents(true)
    var view: BattleSkillPreparationView = panel._project_skills
    assert(view and view._tabs.get_tab_count() == 2)
    assert(other_tree.tiers.size() == 2)
    assert(view._tabs.get_child(1).nodes.size() == 1)
    assert(view._nodes[&"a0"].position == Vector2.ZERO)
    assert(view._nodes[&"p0"].position == Vector2(0, 150))
    assert(view._nodes[&"a3"].position == Vector2(750, 0))
    assert(not view._icon.visible and not view._final.visible)
    await _test_visual_draft(view, fixture, other_tree)
    assert(view.PAYLOAD_PREVIEW.node_text(other_node, 1).contains("Cost: 10 Energy"))
    assert(not view.stage_rank(&"a2", 1), "An unpurchased prerequisite cannot be bypassed.")
    assert(view.stage_rank(&"a0", 1))
    assert(view.stage_rank(&"other_action", 1))
    assert(unit.skills.ledger.spent_points() == 0)
    assert(view._balance.contains("2 pending"))
    view._apply.pressed.emit()
    assert(unit.skills.ledger.spent_points() == 2)
    assert(view._draft.is_empty())
    assert(not view.stage_rank(&"a0", -1), "Minus cannot refund a purchased rank.")
    assert(view.stage_rank(&"a1", 1))
    var proposed := view._preview(view._draft)
    var plan := BattleSkillChainResolver.resolve(proposed.ledger, unit.skills.stat_values())
    assert(view.PAYLOAD_PREVIEW.compiled_text(&"a1", plan).contains("Cost: 20 Energy"))
    view.clear_draft()
    assert(unit.skills.ledger.get_rank(&"a1") == 0)
    assert(view.stage_rank(&"a1", 1))
    # Live gate updates clear an uncommitted draft and invalidate its old buttons.
    var stale_button := _find_add_button(view, &"a0")
    unit.get_stat(CombatStats.STATS.Sanity).set_base(70)
    assert(view._draft.is_empty())
    stale_button.pressed.emit()
    assert(view._draft.is_empty())
    var locked := unit.skills.ledger.explain_requirements(&"a2", unit.skills.stat_values())
    assert(" ".join(locked).contains("Sanity <= 50"))
    assert(view.stage_rank(&"a1", 1))
    var prior_revision: int = unit.skills.revision
    panel.dismiss()
    view.apply_draft()
    assert(unit.skills.revision == prior_revision and unit.skills.ledger.spent_points() == 2)
    party.release_preparation(lease_owner)
    assert(not party.purchase_skills(template.id, {&"a0": 1}, prior_revision, lease_owner).is_empty())
    await free_node(panel)
    await free_node(party)
    await free_node(lease_owner)
    _test_previews()
    await _test_production_layout()


## Recursively finds the positive draft button for the requested node ID, or returns null.
func _find_add_button(parent: Node, node_id: StringName) -> Button:
    for child in parent.get_children():
        if (
            child is Button
            and child.get_meta(&"skill_node_id", &"") == node_id
            and child.get_meta(&"draft_delta", 0) == 1
        ):
            return child
        var found := _find_add_button(child, node_id)
        if found:
            return found
    return null


## Cascades remove only invalid pending purchases; scene controls and scroll survive ordinary edits.
func _test_visual_draft(view: BattleSkillPreparationView, fixture: Dictionary, other_tree: BattleSkillTree) -> void:
    var branch: BattleSkillNode = fixture.collection.trees[0].tiers[0].nodes[2]
    branch.prerequisites[&"a0"] = 2
    var dependent := BattleSkillActionNode.new()
    dependent.id = &"cross_tree_dependent"
    dependent.row = 1
    dependent.prerequisites[&"branch"] = 1
    dependent.action = _action(dependent.id, 1, 0)
    other_tree.tiers[0].nodes.append(dependent)
    # Private fixture definitions are finalized before rebuilding this test visit.
    view.present(view._party, view._unit, view._lease_owner)
    var page: BattleSkillTreePage = view._tabs.get_child(0)
    var button: Button = view._nodes[&"a0"].invest
    var normal: Texture2D = page.connections[0].view.texture
    view._nodes[&"a0"].mouse_entered.emit()
    assert(view._icon.visible and not view._final.visible)
    assert(view._selected_id == &"a0" and view._fallback_id.is_empty())
    var click := InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_LEFT
    click.pressed = true
    view._nodes[&"a0"]._gui_input(click)
    assert(view._fallback_id == &"a0" and view._draft.is_empty())
    view._nodes[&"p0"].hovered.emit(&"p0")
    assert(view._selected_id == &"p0")
    view._nodes[&"p0"].hover_ended.emit(&"p0")
    assert(view._selected_id == &"a0" and view._icon.visible)
    button.pressed.emit()
    assert(view._draft.get(&"a0") == 1 and view._final.visible)
    assert(page.connections[0].view.texture != normal)
    var available: Texture2D = page.connections[0].view.texture
    assert(view.stage_rank(&"a0", 1))
    assert(view.stage_rank(&"a1", 1))
    assert(page.connections[0].view.texture != available)
    assert(view.stage_rank(&"branch", 1))
    view._tabs.current_tab = 1
    assert(not view._icon.visible and not view._final.visible and not view._next.visible)
    assert(view._fallback_id.is_empty() and view._hovered_id.is_empty())
    assert(view.stage_rank(&"cross_tree_dependent", 1))
    assert(view.stage_rank(&"other_action", 1))
    assert(view.stage_rank(&"a0", -1))
    assert(view._draft.get(&"a0") == 1 and view._draft.get(&"a1") == 1)
    assert(not view._draft.has(&"branch") and not view._draft.has(&"cross_tree_dependent"))
    assert(view._draft.has(&"other_action") and view._message.contains("Also removed"))
    assert(view.stage_rank(&"a0", -1))
    assert(not view._draft.has(&"a1") and view._draft.size() == 1)
    assert(page.connections[0].view.texture == normal)
    view._tabs.current_tab = 0
    view._select_node(&"a0")
    assert(not view._final.visible)
    await get_tree().process_frame
    page.scroll.scroll_horizontal = 300
    assert(view.stage_rank(&"a0", 1))
    assert(view._nodes[&"a0"].invest == button and page.scroll.scroll_horizontal == 300)
    assert(view.stage_rank(&"a0", 1) and view.stage_rank(&"a0", 1))
    assert(view._nodes[&"a0"].invest.disabled and view._next.text == "(MAX RANK)")
    assert(not view._nodes[&"a0"].refund.disabled)
    await get_tree().process_frame
    await get_tree().process_frame
    var info_bar := view._info_scroll.get_v_scroll_bar()
    assert(info_bar.max_value > info_bar.page)
    view._info_scroll.scroll_vertical = int(info_bar.max_value)
    await get_tree().process_frame
    await get_tree().process_frame
    assert(view._info_scroll.scroll_vertical > 0)
    var next_bottom := view._next.get_global_rect().end.y
    assert(next_bottom <= view._info_scroll.get_global_rect().end.y + 1)
    var saved_scroll := view._info_scroll.scroll_vertical
    view._nodes[&"p0"].hovered.emit(&"p0")
    view._nodes[&"p0"].hover_ended.emit(&"p0")
    await get_tree().process_frame
    await get_tree().process_frame
    assert(view._selected_id == &"a0" and view._info_scroll.scroll_vertical == saved_scroll)
    view.clear_draft()
    assert(view._draft.is_empty() and not view._final.visible and view._apply.disabled)
    # Exhaust the shared allowance without maxing the node: all Invest controls must disable.
    var other: BattleSkillActionNode = other_tree.tiers[0].nodes[0]
    var original_action := other.action
    other.maximum_rank = 99
    other.action = _action(other.id, 99, 0)
    view.present(view._party, view._unit, view._lease_owner)
    for point in view._unit.skills.earned_points():
        assert(view.stage_rank(other.id, 1))
    assert(view._nodes[other.id].invest.disabled and view._nodes[&"a0"].invest.disabled)
    assert(not view.stage_rank(&"a0", 1))
    view.clear_draft()
    other.maximum_rank = 1
    other.action = original_action
    # Remove the private extra constraints before the original shared-pool regression.
    branch.prerequisites.erase(&"a0")
    other_tree.tiers[0].nodes.erase(dependent)
    view.present(view._party, view._unit, view._lease_owner)


## Accounting uses selected chains, including passive composites and numerical rank gains.
func _test_previews() -> void:
    var f := _fixture()
    var preview = BattleSkillPreparationView.PAYLOAD_PREVIEW
    assert(preview.final_text(f.collection.trees[0].tiers[1].nodes[0], f.ledger).contains("Cost: 30 Energy"))
    var passive: BattleSkillPassiveNode = f.collection.trees[0].tiers[1].nodes[1]
    var text: String = preview.final_text(passive, f.ledger)
    assert(
        (
            text
            == (
                "Physical Resistance: +20\nSelf: Physical Resistance: +3\n"
                + "Physical Resistance: +10\nSelf: Physical Resistance: +3"
            )
        ),
        text
    )
    text = preview.final_text(f.collection.trees[0].tiers[3].nodes[1], f.ledger)
    assert(
        (
            text
            == (
                "Physical Resistance: +10\nSelf: Physical Resistance: +3\n"
                + "Physical Resistance: +10\nSelf: Physical Resistance: +3"
            )
        ),
        text
    )
    var control: BattleSkillPassiveNode = load( # lint:ignore load-in-var -- Load fixtures during test execution.
        "res://GrimDaysBattle/resources/skill_trees/celine/troubled_youth/tier 3/control_node.tres"
    )
    assert(preview.next_text(control, 1).contains("Lucidity: +5% -> +10%"))
    assert(preview.next_text(control, 5) == "(MAX RANK)")
    var chain := EffectTriggerAnotherEffect.new()
    chain.chance = 25
    var effect := EffectResourceChangeTemplate.new()
    effect.amount = -10
    effect.stat = CombatStats.STATS.Health
    effect.duration = 2
    effect.lifetime = EffectTemplate.LIFETIME.ROUNDS
    chain.triggers = [effect]
    text = preview.effect_text(chain)
    assert(text == "Self: 25% chance:\nSelf: Damage: 10 (for 2 rounds)", text)
    var changed := effect.duplicate() as EffectResourceChangeTemplate
    changed.amount = -15
    text = "\n".join(preview._effects_delta([effect], [changed]))
    assert(text == "Self: Damage: 10 (for 2 rounds) -> Self: Damage: 15 (for 2 rounds)", text)


## The user's one-based scene rows map to resource indices 2 and 4, with no sixth row.
func _test_production_layout() -> void:
    var page := BattleSkillPreparationView.PAGE_SCENE.instantiate() as BattleSkillTreePage
    add_child(page)
    assert(page.populate(CELINE_TEMPLATE.skill_collection.trees[0]).is_empty())
    assert(page.nodes[&"straight_punch_node"].icon.texture != BattleSkillNodeView.PLACEHOLDER)
    assert(page.nodes[&"straight_punch_node"].position == Vector2(0, 300))
    assert(page.nodes[&"control"].position == Vector2(500, 600))
    assert(page.canvas.custom_minimum_size == Vector2(1900, 760))
    await free_node(page)
    var tree := BattleSkillTree.new()
    tree.id = &"empty_test"
    page = BattleSkillPreparationView.PAGE_SCENE.instantiate() as BattleSkillTreePage
    add_child(page)
    assert(page.populate(tree).is_empty() and page.nodes.is_empty())
    var tier := BattleSkillTier.new()
    tier.column = 7
    var edge := BattleSkillActionNode.new()
    edge.id = &"last_cell"
    edge.row = 4
    edge.action = _action(edge.id, 1, 0)
    tier.nodes = [edge]
    tree.tiers = [tier]
    assert(page.populate(tree).is_empty())
    assert(page.nodes[edge.id].position == Vector2(1750, 600))
    await free_node(page)
