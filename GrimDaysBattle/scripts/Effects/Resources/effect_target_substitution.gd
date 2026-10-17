extends EffectTemplate
## Fixed ally binding installed by an action and invoked by the owner's TARGETED response.
class_name EffectTargetSubstitutionTemplate

enum BOUND_UNIT { SELECTED_ALLY, APPLIER }

## SELF owner + SELECTED_ALLY redirects the caster; ALLY owner + APPLIER protects the selected ally.
@export var bound_unit: BOUND_UNIT = BOUND_UNIT.SELECTED_ALLY
