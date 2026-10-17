extends RefCounted
## Mutable inventory stack created from immutable authored item data.
class_name ItemBase

## Authored [ItemTemplate] definition shared by every stack of this item. This
## remains typed as [Resource] to avoid a circular compile dependency because
## [ItemTemplate] itself exposes [enum ItemBase.TYPE].
var template: Resource
## Number of items currently held by this stack.
var count: int = 1
## Individual equipment identity, retained while stored, transferred or equipped.
## Ordinary consumable stacks do not need an equipment grant identity.
var instance_id: StringName

## Stable authored identifier used to compare and persist item stacks.
var id: StringName:
    get:
        return template.id if template else &""

## Maximum number of items that may occupy one inventory slot.
var stack_size: int:
    get:
        return maxi(template.stack_size, 1) if template else 1

## Enumerates the supported type values.
enum TYPE {
    QUEST = 2,
    KEY = 3,
    CONSUMABLE = 0,
    BODY_ARMOR = 1,
    RING = 5,
    NECKLACE = 6,
    WEAPON = 4,
    BOOK = 7,
    MATERIAL = 8,
    CURRENCY = 9,
}


## Creates a runtime stack without modifying the authored [ItemTemplate].
## [param amount] may exceed [member stack_size] while the stack is in transit;
## [Inventory] splits it into legal slot-sized stacks when it is added.
static func create(item_template: Resource, amount: int = 1, equipment_id: StringName = &"") -> ItemBase:
    if not item_template or amount < 1:
        return null
    var new_item: ItemBase = ItemBase.new()
    new_item.template = item_template
    new_item.count = amount
    new_item.instance_id = equipment_id
    return new_item


## Allocates identity only when an inventory accepts an individual equipment item.
func ensure_instance_id() -> void:
    if instance_id.is_empty():
        instance_id = StringName(Crypto.new().generate_random_bytes(16).hex_encode())


## Consumes [param amount] from this stack. Invalid or unaffordable requests do
## not change the stack.
func use(amount: int = 1) -> bool:
    if amount < 1 or amount > count:
        return false
    count -= amount
    return true
