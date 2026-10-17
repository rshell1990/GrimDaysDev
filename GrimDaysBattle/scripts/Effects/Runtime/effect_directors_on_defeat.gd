extends EffectDirectors
#region EFFECT ON DEFEAT
## An effect director, concerned with running effects after it's owner has been defeated.
class_name EffectDirectorsOnDefeat
#endregion


#region MAIN
## Add the supplied effect to this director. Uses the base class' version of this function at first.
func add_effect(sender: Node, target: Node, template: EffectTemplate, context: Dictionary = {}) -> EffectBase:
    return super(sender, target, template, context)
