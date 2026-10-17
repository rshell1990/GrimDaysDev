extends EffectDirectors
#region EFFECT BEFORE HIT
## An effect director, concerned with running effects before it's owner has been hit.
class_name EffectDirectorsBeforeHit
#endregion


#region MAIN
## Add the supplied effect to this director. Uses the base class' version of this function at first.
func add_effect(sender: Node, target: Node, template: EffectTemplate, context: Dictionary = {}) -> EffectBase:
    return super(sender, target, template, context)
