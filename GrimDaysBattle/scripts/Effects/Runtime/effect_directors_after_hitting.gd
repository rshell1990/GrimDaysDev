extends EffectDirectors
#region AFTER HITTING
## An effect director, concerned with running effects after it's owner has successfully hit it's target.
class_name EffectDirectorsAfterHitting
#endregion


#region MAIN
## Add the supplied effect to this director. Uses the base class' version of this function at first.
func add_effect(sender: Node, target: Node, template: EffectTemplate, context: Dictionary = {}) -> EffectBase:
    return super(sender, target, template, context)
