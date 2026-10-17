extends Control
## One authored tab page with absolute-positioned nodes over decorative connections.
class_name BattleSkillTreePage

const NODE_SCENE = preload("res://GrimDaysBattle/scenes/ui/skill_tree/node_base.tscn")
const LINE_SCRIPT = preload("res://GrimDaysBattle/scripts/UI/skill_tree_line_texture_control.gd")
const CELL_SIZE = Vector2(250, 150)
const NODE_SIZE = Vector2(144, 144)
const ROW_COUNT = 5
const TIER_COUNT = 8

var tree_id: StringName
var nodes: Dictionary = {}
var connections: Array[Dictionary] = []
@onready var canvas: Control = %"Node Container"
@onready var scroll: ScrollContainer = $MarginContainer/ScrollContainer


## Resource coordinates remain zero-based; only the visible scene names are one-based.
func populate(tree: BattleSkillTree) -> PackedStringArray:
    tree_id = tree.id
    var errors := PackedStringArray()
    var definitions: Dictionary = {}
    var columns: Dictionary = {}
    for tier in tree.get_runtime_tiers():
        for node in tier.nodes:
            if node.row < 0 or node.row >= ROW_COUNT or tier.column < 0 or tier.column >= TIER_COUNT:
                errors.append("%s is outside the panel's five rows and eight tiers." % node.get_display_name())
                continue
            definitions[node.id] = node
            columns[node.id] = tier.column
    for node: BattleSkillNode in definitions.values():
        if node.previous_node.is_empty() or not definitions.has(node.previous_node):
            continue
        var line := TextureRect.new()
        line.set_script(LINE_SCRIPT)
        line.mouse_filter = Control.MOUSE_FILTER_IGNORE
        line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        line.stretch_mode = TextureRect.STRETCH_SCALE
        line.position = Vector2(columns[node.previous_node] * CELL_SIZE.x + 75, node.row * CELL_SIZE.y + 75)
        line.size = Vector2((columns[node.id] - columns[node.previous_node]) * CELL_SIZE.x + 5, 34)
        canvas.add_child(line)
        connections.append({"from": node.previous_node, "to": node.id, "view": line})
    for node: BattleSkillNode in definitions.values():
        var view := NODE_SCENE.instantiate() as BattleSkillNodeView
        view.name = "Tier %s Row %s" % [columns[node.id] + 1, node.row + 1]
        canvas.add_child(view)
        view.position = Vector2(columns[node.id], node.row) * CELL_SIZE
        view.size = NODE_SIZE
        view.configure(node)
        nodes[node.id] = view
    return errors


func refresh_connections(ledger: BattleSkillInvestment) -> void:
    for connection in connections:
        if ledger.get_rank(connection.from) == 0:
            connection.view.set_exists_texture()
        elif ledger.get_rank(connection.to) == 0:
            connection.view.set_available_texture()
        else:
            connection.view.set_completed_texture()
