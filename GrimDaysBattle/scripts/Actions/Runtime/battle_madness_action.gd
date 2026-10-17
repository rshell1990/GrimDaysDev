extends ActionTemplate
## Ephemeral madness-only choices. They consume a turn, not learned-action grants.
class_name BattleMadnessAction

enum KIND { COWER, CATATONIC }
var kind: KIND


static func available(unit: BattleUnit) -> Array[ActionTemplate]:
    var actions: Array[ActionTemplate] = []
    if not is_instance_valid(unit) or not unit.has_madness():
        return actions
    for choice in KIND.values():
        var action := BattleMadnessAction.new()
        action.kind = choice
        action.id = &"madness_cowering" if choice == KIND.COWER else &"madness_catatonic"
        action.display_name = "Cowering" if choice == KIND.COWER else "Catatonic"
        action.target = CombatActions.TARGET.SELF
        action.target_amount = 1
        action.always_hits = true
        actions.append(action)
    return actions


func can_use(unit: BattleUnit) -> bool:
    return is_instance_valid(unit) and unit.is_active and unit.has_madness() and kind in KIND.values()
