extends RefCounted
## Per-unit purchases, separate from current availability and derived battle grants.
## No Yggdrasil types or standalone addon saves. A trusted party service must supply
## earned points/current stats and authorize preparation/reset before calling this.
## Definitions remain immutable after setup; they are shared, not copied into saves.
class_name BattleSkillInvestment

## Monotonic ledger version used to reject stale purchase and reset requests.
var revision: int = 0
## Validated node definitions indexed by collection-wide ID.
var _nodes: Dictionary = {}
## Owning tier for each configured node ID.
var _tiers: Dictionary = {}
## Purchased ranks indexed by node ID; availability never erases these values.
var _ranks: Dictionary = {}
## Whether a collection has successfully configured this ledger.
var _configured: bool = false
## Shared authoring collection retained for later validation.
var _definitions: BattleSkillTreeCollection
## Owning tree identity for each configured node ID.
var _tree_ids: Dictionary = {}


## Invalid definitions leave a previously configured ledger untouched.
func configure(definitions: BattleSkillTreeCollection) -> PackedStringArray:
    if not definitions:
        return PackedStringArray(["Missing skill collection."])
    var errors := definitions.validate()
    if not errors.is_empty():
        return errors
    _nodes.clear()
    _tiers.clear()
    _tree_ids.clear()
    _definitions = definitions
    _ranks.clear()
    for tree in definitions.trees:
        for tier in tree.tiers:
            for node in tier.nodes:
                _nodes[node.id] = node
                _tree_ids[node.id] = tree.id
                _tiers[node.id] = tier
    _configured = true
    revision += 1
    return []


## Read-only definition view for the chain compiler. Resources remain immutable;
## callers receive an independent array, never the investment dictionary.
func get_nodes() -> Array[BattleSkillNode]:
    var result: Array[BattleSkillNode] = []
    result.assign(_nodes.values())
    return result


## The owning tier is the sole source of a node's grid column.
func get_column(node_id: StringName) -> int:
    return _tiers[node_id].column if _tiers.has(node_id) else -1


## Returns the owning tree ID for a configured node, or an empty StringName for an unknown ID.
func get_tree_id(node_id: StringName) -> StringName:
    return _tree_ids.get(node_id, &"")


## Revalidates the shared collection, or reports that the ledger has not been configured.
func validate_definitions() -> PackedStringArray:
    return _definitions.validate() if _configured else PackedStringArray(["Skill ledger is not configured."])


## Returns the purchased rank for this node, defaulting to zero.
func get_rank(node_id: StringName) -> int:
    return int(_ranks.get(node_id, 0))


## Sums purchased ranks across every tree in the unit's collection.
func spent_points() -> int:
    var total: int = 0
    for rank: int in _ranks.values():
        total += rank
    return total


## Returns earned points minus all purchases, clamped to zero.
func available_points(earned_points: int) -> int:
    return maxi(0, earned_points - spent_points())


## Purchase a whole draft atomically. One point buys one rank across all trees.
## No negative deltas/refunds. Stale UI revisions and any invalid node reject all.
func purchase(
    additions: Dictionary, earned_points: int, stat_values: Dictionary, expected_revision: int
) -> PackedStringArray:
    if not _configured or expected_revision != revision or additions.is_empty() or earned_points < 0:
        return PackedStringArray(["Invalid or stale skill purchase."])
    var candidate := _ranks.duplicate()
    for key in additions:
        if not (key is String or key is StringName) or not additions[key] is int or additions[key] <= 0:
            return PackedStringArray(["Skill purchases require node IDs and positive whole ranks."])
        var id := StringName(key)
        if not _nodes.has(id):
            return PackedStringArray(["Unknown skill node: %s." % id])
        # Bound the addition before arithmetic to avoid overflow from malformed input.
        if additions[key] > _nodes[id].maximum_rank - int(candidate.get(id, 0)):
            return PackedStringArray(["Skill rank exceeds its authored maximum: %s." % id])
        candidate[id] = int(candidate.get(id, 0)) + additions[key]
    var errors := _validate_ranks(candidate, earned_points)
    if not errors.is_empty():
        return errors
    for key in additions:
        if not _available(StringName(key), candidate, stat_values):
            return PackedStringArray(["Skill requirements are not met: %s." % key])
    _ranks = candidate
    revision += 1
    return []


## Current eligibility never changes purchases or refunds points. Consumers must
## use this for passive suppression/action fallback rather than deleting ranks.
func is_available(node_id: StringName, stat_values: Dictionary) -> bool:
    return _configured and _available(node_id, _ranks, stat_values)


## Human-readable gate/prerequisite failures, including unavailable ancestors.
## The node itself need not be purchased: preparation uses this to explain why
## its next rank is locked. A draft ledger can include staged prerequisite ranks.
func explain_requirements(node_id: StringName, values: Dictionary) -> PackedStringArray:
    var reasons := PackedStringArray()
    if not _configured or not _nodes.has(node_id):
        return PackedStringArray(["Unknown skill node."])
    var node: BattleSkillNode = _nodes[node_id]
    for definition in [_tiers[node_id], node]:
        for constraint in [[definition.minimum_stats, true], [definition.maximum_stats, false]]:
            var bounds: Dictionary = constraint[0]
            var is_minimum: bool = constraint[1]
            for stat in bounds:
                var current: Variant = values.get(stat)
                var label := CombatStats.get_stat_as_string(stat)
                if not (current is int or current is float) or not is_finite(float(current)):
                    reasons.append("Missing valid %s." % label)
                elif (is_minimum and current < bounds[stat]) or (not is_minimum and current > bounds[stat]):
                    var comparison := ">=" if is_minimum else "<="
                    reasons.append("%s %s %s (current %s)." % [label, comparison, bounds[stat], current])
    for prerequisite in BattleSkillTreeCollection.dependencies(node):
        var required: int = BattleSkillTreeCollection.dependencies(node)[prerequisite]
        if get_rank(prerequisite) < required:
            reasons.append("Requires %s rank %s." % [prerequisite, required])
        elif not is_available(prerequisite, values):
            reasons.append(
                "Requires available %s: %s" % [prerequisite, " ".join(explain_requirements(prerequisite, values))]
            )
    return reasons


## Recursively checks purchased rank, owning-tier and node bounds, and prerequisite availability.
## Definitions must have passed cycle validation during configuration.
func _available(id: StringName, ranks: Dictionary, values: Dictionary) -> bool:
    if not _nodes.has(id) or int(ranks.get(id, 0)) < 1:
        return false
    var node: BattleSkillNode = _nodes[id]
    var tier: BattleSkillTier = _tiers[id]
    if (
        not _bounds_met(tier.minimum_stats, tier.maximum_stats, values)
        or not _bounds_met(node.minimum_stats, node.maximum_stats, values)
    ):
        return false
    for prerequisite in BattleSkillTreeCollection.dependencies(node):
        if (
            int(ranks.get(prerequisite, 0)) < BattleSkillTreeCollection.dependencies(node)[prerequisite]
            or not _available(prerequisite, ranks, values)
        ):
            return false
    return true


## Requires finite numeric values for every bound and applies inclusive minimum/maximum
## comparisons.
static func _bounds_met(minimum: Dictionary, maximum: Dictionary, values: Dictionary) -> bool:
    for bounds in [minimum, maximum]:
        for stat in bounds:
            if (
                not values.has(stat)
                or not (values[stat] is int or values[stat] is float)
                or not is_finite(float(values[stat]))
            ):
                return false
    for stat in minimum:
        if values[stat] < minimum[stat]:
            return false
    for stat in maximum:
        if values[stat] > maximum[stat]:
            return false
    return true


## Definition references, availability, grants and UI revisions are not save data.
func capture() -> Dictionary:
    return {"version": 1, "ranks": _ranks.duplicate()}


## Reject the whole payload on corruption/schema drift; never silently lose paid
## ranks. Availability is deliberately not checked: Sanity may currently lock them.
## JSON whole-number floats are accepted, booleans/fractions/nonfinite values are not.
func restore(data: Variant, earned_points: int) -> PackedStringArray:
    if (
        not data is Dictionary
        or not _configured
        or not _whole_number(data.get("version"))
        or data.version != 1
        or not data.get("ranks") is Dictionary
    ):
        return PackedStringArray(["Invalid skill investment save schema."])
    var candidate: Dictionary = {}
    for key in data.ranks:
        var amount: Variant = data.ranks[key]
        if not (key is String or key is StringName) or not _whole_number(amount) or amount < 1 or amount > 99:
            return PackedStringArray(["Invalid saved skill rank."])
        candidate[StringName(key)] = int(amount)
    var errors := _validate_ranks(candidate, earned_points)
    if not errors.is_empty():
        return errors
    _ranks = candidate
    revision += 1
    return []


## Rejects unknown nodes, invalid ranks, overspending and missing purchased prerequisites without
## changing the ledger.
func _validate_ranks(ranks: Dictionary, earned_points: int) -> PackedStringArray:
    var total: int = 0
    for key in ranks:
        var node: BattleSkillNode = _nodes.get(key)
        if not node or ranks[key] < 1 or ranks[key] > node.maximum_rank:
            return PackedStringArray(["Unknown skill node or out-of-range saved rank."])
        if earned_points < 0 or ranks[key] > earned_points - total:
            return PackedStringArray(["Insufficient unit skill points."])
        total += int(ranks[key])
        for prerequisite in BattleSkillTreeCollection.dependencies(node):
            if int(ranks.get(prerequisite, 0)) < BattleSkillTreeCollection.dependencies(node)[prerequisite]:
                return PackedStringArray(["Missing purchased prerequisite rank."])
    if earned_points < 0:
        return PackedStringArray(["Invalid earned skill points."])
    return []


## Accepts only finite integer-valued numbers, including whole JSON floats; booleans are excluded.
static func _whole_number(value: Variant) -> bool:
    return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))


## Internal reset operation for an authorized story/vendor/item service, never an
## individual-node refund or ordinary preparation button. Returns refunded points.
func reset_all(expected_revision: int) -> int:
    if not _configured or expected_revision != revision:
        return -1
    var refunded := spent_points()
    _ranks.clear()
    revision += 1
    return refunded
