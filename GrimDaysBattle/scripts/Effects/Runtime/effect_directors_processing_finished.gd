extends EffectDirectors
## Implements the runtime effect directors processing finished behavior used by the battle effect pipeline.
class_name EffectDirectorsProcessingFinished


#region MAIN
## Add the supplied effect to this director. Uses the base class' version of this function at first.
func add_effect(sender: Node, target: Node, template: EffectTemplate, context: Dictionary = {}) -> EffectBase:
    return super(sender, target, template, context)
