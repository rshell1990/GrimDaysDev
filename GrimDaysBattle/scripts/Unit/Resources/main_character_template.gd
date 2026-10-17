# Editor configuration for MainCharacterTemplate.
@tool
extends BattleUnitTemplate
## Coordinates main character template behavior for the battle system.
class_name MainCharacterTemplate

@export_group("Lucidity Break")
## Weighted potential effects or immediate actions; empty/all-zero tables disable breaks.
@export var lucidity_break_options: Array[LucidityBreakOption] = []


## Returns whether main.
func is_main() -> bool:
    return true
