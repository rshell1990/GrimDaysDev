extends Node
## Contains information about all the tooltip resources that have been created for the
## various information displayed when a UI element is hovered for an extended period.

## The resource that contains a list of the tooltip resources.
@export var resource: TooltipResources

## The dictionary accessed by other parts of the project.
var master: Dictionary


## Builds this repository’s lookup table from its assigned resources when the node is ready.
func _ready():
    if resource == null:
        return
    for tooltip in resource.all:
        master[tooltip.id] = tooltip
