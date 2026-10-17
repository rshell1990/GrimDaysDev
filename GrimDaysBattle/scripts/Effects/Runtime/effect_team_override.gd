extends EffectBase
## Implements the runtime effect team override behavior used by the battle effect pipeline.
class_name EffectTeamOverride

## Runtime effect template state used by this effect team override.
var effect_template: EffectTeamOverrideTemplate
## Runtime affected unit state used by this effect team override.
var affected_unit: BattleUnit


## Initializes this effect team override from the supplied runtime dependencies.
func setup(sent_by: Variant, target_node: Variant, template: Variant) -> void:
    super(sent_by, target_node, template)
    effect_template = template


## Applies this effect team override's configured behavior to its current target.
func apply() -> void:
    if not _begin_apply():
        return
    affected_unit = targeting as BattleUnit
    if not affected_unit or not effect_template or effect_template.team_id.is_empty():
        CustomLogger.error(
            self, apply, "Team override requires a BattleUnit and non-empty team ID.", CustomLogger.LEVEL.IMPORTANT
        )
        _finish_apply()
        return
    affected_unit.add_team_override(self, effect_template.team_id)
    _finish_apply()


## Reverses revoke for this effect team override.
func _revoke() -> void:
    if affected_unit:
        affected_unit.remove_team_override(self)
    affected_unit = null


## Releases owned state and signal-driven effects before this node leaves the scene tree.
func _exit_tree() -> void:
    _revoke()
