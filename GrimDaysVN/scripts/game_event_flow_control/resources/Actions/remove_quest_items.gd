## Inactive quest-item removal prototype. The commented GameAction implementation does not execute
## or consume inventory items.

#extends GameAction
#class_name GameActionRemoveQuestVNItems
#
#@export var items:Array[VNItemTemplate]
#
#func execute() -> void:
#var player:PlayerOperator = SystemHelpers.get_player()
#for item in items:
#player.use_item(item.id)
#
