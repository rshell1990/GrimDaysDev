## Inactive inventory-grid prototype retained as commented reference. No bindings, slot creation or
## runtime callbacks are active.

#extends GridContainer
#signal bind_ui(ui)
#
#@export var item_template:PackedScene
#@export var items_per_page:int
#
#var max_pages:int
#var current_page:int = 0
#var items:Array[BattleVNItem]
#var inventory:Inventory:
#get:
#return inventory
#set(value):
#inventory = value
#init_ui()
#
#func _ready():
#VNSignalBus.listen_for(bind_ui,VNSignalBus._on_inventory_bind_request)
#bind_ui.emit(self)
#
#func init_ui():
#for child in get_children():
#child.free()
#var active_items = inventory.items
#print(active_items)
#for id in active_items.keys():
#print(id)
#print(Repositories.get_info(RepositoryTypes.ITEMS, id).display_name)
#var battle_item = item_template.instantiate()
#battle_item.bind_item(Repositories.get_info(RepositoryTypes.ITEMS, id), active_items[id])
#add_child(battle_item)
