extends ItemTemplate
## Inventory supplies authority and payment; referenced actions supply battle behavior.
class_name ConsumableTemplate

## Whether this item can currently be selected in battle.
@export var usable_in_battle: bool
## Usually one unique action. Separate definitions preserve alternate targeting modes.
## Each choice executes rank one and consumes one item, ignoring stat costs/cooldowns.
@export var battle_actions: Array[ActionTemplate] = []
