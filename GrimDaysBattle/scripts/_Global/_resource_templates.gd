extends Resource
#region TEMPLATES
## A generic resource to store all resources of a specific type, that is then referenced
## to create a global repository.
##
class_name ResourceTemplates
#endregion

#region MASTER RECORD
## A list of all the resources to build this repository of resources.
@export var all: Array[ResourceTemplate]
