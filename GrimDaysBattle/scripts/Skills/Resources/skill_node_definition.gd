# Editor configuration for BattleSkillNode.
@tool
@abstract
extends Resource
## Immutable authoring data, never a purchased rank. IDs are unique across a
## unit's collection so prerequisites and saved investments are unambiguous.
class_name BattleSkillNode

## Collection-wide stable node identity used by prerequisites and saved ranks.
@export var id: StringName
## Human-readable node label; views may fall back to the ID.
@export var display_name: String
## Optional presentation overrides; action nodes fall back to their action metadata.
@export var icon: Texture2D
@export_multiline var description: String
## Zero-based grid row within the owning tier; only same-row predecessors compose effects.
@export_range(0, 99, 1) var row: int = 0
## Maximum purchasable rank; the payload must supply every rank through this limit.
@export_range(1, 99, 1) var maximum_rank: int = 1
## Every listed node must have at least this purchased rank and be available.
@export var prerequisites: Dictionary[StringName, int] = {}
@export var minimum_stats: Dictionary[CombatStats.STATS, float] = {}
@export var maximum_stats: Dictionary[CombatStats.STATS, float] = {}
## Optional same-row predecessor; also implicitly requires its first rank.
## Cross-row prerequisites never contribute effects to a composite.
@export var previous_node: StringName
## False replaces the preceding chain; true retains it. Purchasing never erases
## preceding investments, even when their runtime grants are suppressed.
@export var composite: bool = false

## Payload strategies implement validation, chain compatibility and plan generation.
@abstract func validate_payload(errors: PackedStringArray) -> void

@abstract func accepts_predecessor(previous: BattleSkillNode) -> bool

@abstract func get_payload_label() -> String

@abstract func append_chain_plan(
    source: StringName,
    components: Array[BattleSkillNode],
    ledger: BattleSkillInvestment,
    signature: Array,
    result: Dictionary
) -> void


## Only action strategies reserve chain action IDs for cooldown save/restore.
func has_action_source() -> bool:
    return false


## Presentation defaults preserve node identities when metadata is absent.
func get_display_name() -> String:
    return display_name if not display_name.is_empty() else String(id)


func get_display_icon() -> Texture2D:
    return icon


func get_description() -> String:
    return description
