extends EffectDirectors
#region EFFECT ON EQUIP
## Applies equipment grants immediately. Their explicit lifetime determines
## whether they are removed after application, by source removal, or at battle end.
class_name EffectDirectorsOnEquip
#endregion


#region MAIN
## Add the supplied effect to this director. Uses the base class' version of this function at first.
func add_effect(sender: Node, target: Node, template: EffectTemplate, context: Dictionary = {}) -> EffectBase:
    var added_effect: EffectBase = super(sender, target, template, context)
    if not incoming_effect:
        return null

    if template.lifetime != EffectTemplate.LIFETIME.INSTANT:
        incoming_effect.apply()
    return added_effect
