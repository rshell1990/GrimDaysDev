extends Resource

## Information related to a particular tooltip.
## Authored header and description for a tooltip.
class_name TooltipResource

## The identifier of the tooltip that is used to access the header and text information.
@export var id: String

## The header of the tooltip, it is displayed above the seperating line of a tooltip.
@export var header: String

## The main body of the tooltip, this will provide the detailed explanation of the item that is hovered.
@export_multiline var description: String
