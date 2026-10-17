# Editor configuration for BattleSkillTier.
@tool
extends Resource
## One grid column. All inclusive stat bounds must be satisfied to invest/use it.
## Runtime values are supplied by the unit adapter (Level, current Sanity, etc.).
class_name BattleSkillTier

## Grid column shared by every node owned by this tier.
@export_range(0, 99, 1) var column: int = 0
## A tier requires at least one node; its column applies to every node here.
@export var nodes: Array[BattleSkillNode] = []
@export var minimum_stats: Dictionary[CombatStats.STATS, float] = {}
@export var maximum_stats: Dictionary[CombatStats.STATS, float] = {}
