# Editor configuration for UnitCalculatedStatTemplate.
@tool
extends UnitStatTemplate
## Coordinates unit calculated stat template behavior for the battle system.
class_name UnitCalculatedStatTemplate

## Configures the influenced by used by this unit calculated stat template.
@export var influenced_by: CombatStats.STATS
## Per-point gains for attribute-derived stats. Level is the explicit exception:
## its curve maps total Experience directly to earned Level.
@export var growth_curve: Curve


## Rebuilds the unmodified total, never adding to the previous runtime value.
## The starting amount is added once, before the runtime modifier ledger.
func calculate_base(influencing_value: float) -> float:
    if type == CombatStats.STATS.Level:
        return starting_amount + growth_curve.sample(influencing_value)
    return starting_amount + cumulative_growth(growth_curve, influencing_value)


## Each whole point n grants curve(n). Fractional influence grants that fraction
## of the next point's gain (5.5 = gains 1..5 plus half of gain 6). Zero/negative
## influence grants nothing. Outside the authored domain, endpoint gains continue;
## the constant upper tail is multiplied rather than iterated for large values.
static func cumulative_growth(curve: Curve, influencing_value: float) -> float:
    var points := maxf(influencing_value, 0.0)
    var whole_points := floorf(points)
    var sampled_points := int(minf(whole_points, maxf(floorf(curve.max_domain), 0.0)))
    var total := 0.0
    for point in range(1, sampled_points + 1):
        total += curve.sample(clampf(point, curve.min_domain, curve.max_domain))
    total += (whole_points - sampled_points) * curve.sample(curve.max_domain)
    var fraction := points - whole_points
    if fraction > 0.0:
        total += fraction * curve.sample(clampf(whole_points + 1.0, curve.min_domain, curve.max_domain))
    return total
