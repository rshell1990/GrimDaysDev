extends Resource
class_name VNItemTemplate

enum CATEGORY {
    CURRENCY,
    ARMOR,
    WEAPON,
    BOOK,
    CONSUMABLE,
    SHIELD,
    ACCESSORY,
    QUEST,
    KEY,
    MATERIAL,
    TOOL,
    MISCELLANEOUS,
}

@export var id: Variant
@export var display_name: String
@export_multiline var description: String
@export var icon: Resource
@export var category: CATEGORY = CATEGORY.MISCELLANEOUS
@export var max_stack: int = 1
@export var cash_value: int
@export var types: Array[int] = []
@export var positive_effects: Array[Resource] = []
@export var negative_effects: Array[Resource] = []
@export var battle_stats: Dictionary = {}
@export var use_effects: Array[Dictionary] = []
@export var can_use_with_other: bool = false
