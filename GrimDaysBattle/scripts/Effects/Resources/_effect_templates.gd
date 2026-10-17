extends ResourceTemplate
#region EFFECT TEMPLATES
## A class to create a resource to hold all the effect templates, will be used to build a repository of them that can be
## accessed globally.

## Implements the runtime effect templates behavior used by the battle effect pipeline.
class_name EffectTemplates
#endregion

#region VARIABLES
## The array that holds all effect templates.
@export var all: Array[EffectTemplate]
#endregion


## Returns organized effects for this effect templates.
func get_organized_effects() -> Dictionary:
    var effects: Dictionary

    for template in all:
        if not template:
            continue
        if not effects.has(template.trigger):
            effects.set(template.trigger, [template])
            continue

        effects[template.trigger].append(template)

    return effects
