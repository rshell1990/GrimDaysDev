## Inactive inventory-action prototype. The former GameAction implementation is entirely commented
## out and does not grant items.

#extends GameAction
#class_name GameActionAddVNItem
#
#@export var item:VNItemTemplate
#@export var amount:int
#
#func execute() -> void:
#var player = SystemHelpers.get_player()
#player.add_item(item.id, amount)
