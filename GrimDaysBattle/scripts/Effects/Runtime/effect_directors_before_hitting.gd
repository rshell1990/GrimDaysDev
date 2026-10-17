extends EffectDirectors
#region BEFORE HITTING
## An effect director, concerned with running effects before it's owner has hit it's target.
class_name EffectDirectorsBeforeHitting
#endregion


#region MAIN
## Add the supplied effect to this director. Uses the base class' version of this function at first.
func add_effect(sender: Node, target: Node, template: EffectTemplate, context: Dictionary = {}) -> EffectBase:
    return super(sender, target, template, context)
