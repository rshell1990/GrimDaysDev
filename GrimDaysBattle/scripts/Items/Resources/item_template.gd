extends ResourceTemplate
#region ITEM TEMPLATE
## The base template for every type of item (consumbale/equipment).
##
class_name ItemTemplate
#endregion

#region BASIC
@export_category("Basic")
## The name displayed in the UI for the unit.
@export var display_name: String
## The 'class' that the item is.
@export var item_class: ItemBase.TYPE
## How many items can occupy the same inventory 'slot'.
@export var stack_size: int = 1
## The icon for the item.
@export var icon: Texture2D
## The item's description.
@export_multiline var description: String
## Will this drop after a battle.
@export var lootable: bool
## The maximum vendor cost of the item, before barter.
@export var value: int
#endregion
