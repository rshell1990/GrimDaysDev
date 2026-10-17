extends ActionTemplate
## Ephemeral action backed by one owned consumable stack. Never learned, equipped,
## ranked or saved as action ownership; inventory state is its only authority.
class_name BattleItemAction

## Authored item used for labels and combat-event metadata.
var item: ConsumableTemplate
## Owning inventory checked before the consumable can be used.
var _inventory: Inventory
## Exact stack instance backing this ephemeral action choice.
var _stack: ItemBase
## Prevents the same ephemeral choice from consuming more than once.
var _consumed: bool
## Referenced behavior, retained to reject choices after their definition is replaced.
var definition: ActionTemplate


## Creates rank-one choices backed by exact personal inventory stacks.
static func available(unit: BattleUnit) -> Array[ActionTemplate]:
    var result: Array[ActionTemplate] = []
    if not is_instance_valid(unit) or not unit.inventory:
        return result
    for slot in range(1, unit.inventory.size + 1):
        var stack: ItemBase = unit.inventory.slots.get(slot)
        if not stack or not stack.template is ConsumableTemplate or stack.count < 1:
            continue
        var item_template: ConsumableTemplate = stack.template
        if not item_template.usable_in_battle or item_template.id.is_empty():
            continue
        for action_definition in item_template.battle_actions:
            if not _valid_definition(action_definition):
                continue
            var action := BattleItemAction.new()
            action.item = item_template
            action.definition = action_definition
            action._inventory = unit.inventory
            action._stack = stack
            # Copy the action's exported behavior without mutating its authored resource.
            for property in action_definition.get_property_list():
                if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
                    action.set(property.name, action_definition.get(property.name))
            action.disabled_by_effects = action_definition.disabled_by_effects.duplicate()
            result.append(action)
    return result


## Require an executable first rank; later ranks never affect item execution.
static func _valid_definition(action: ActionTemplate) -> bool:
    if not action or action.id.is_empty() or not action.validate_restrictions().is_empty():
        return false
    var rank := action.get_rank_template(1)
    return rank != null and rank.effects != null and not rank.effects.all.is_empty()


## Validate the original stack reference, not a numeric slot that may now hold a
## different item after compaction, load or retry. No other owner's fallback exists.
func can_use(unit: BattleUnit) -> bool:
    return (
        not _consumed
        and is_instance_valid(unit)
        and unit.is_active
        and is_instance_valid(_inventory)
        and unit.inventory == _inventory
        and _stack
        and _stack.count > 0
        and _stack.template == item
        and item.usable_in_battle
        and _inventory.slots.values().has(_stack)
        and definition in item.battle_actions
        and _valid_definition(definition)
    )


## Pays one item exactly once at action commit, never at menu/target selection.
func consume(unit: BattleUnit) -> bool:
    if not can_use(unit):
        return false
    for slot in range(1, _inventory.size + 1):
        if _inventory.slots[slot] == _stack:
            _consumed = _inventory.use_item(slot, 1)
            return _consumed
    return false


## Current remaining quantity for production menu labels.
func remaining_count() -> int:
    return _stack.count if _stack else 0


## Exact identity for inventory-slot UI mapping.
func matches_stack(stack: ItemBase) -> bool:
    return stack != null and stack == _stack
