@tool
extends DialogicEvent
class_name DialogicCharacterAddEvent

# Define properties of the event here
var id:StringName
var method:StringName
var depth:StringName
var start:float
var end:float
var flipped:bool

func _execute() -> void:
	# This will execute when the event is reached
	finish() # called to continue with the next event


#region INITIALIZE
################################################################################
# Set fixed settings of this event
func _init() -> void:
	event_name = "Character Add"
	event_category = "Visual"



#endregion

#region SAVING/LOADING
################################################################################
func get_shortcode() -> String:
	return "character-add"

func get_shortcode_parameters() -> Dictionary:
	return {
		#param_name 		: property_info
		#"my_parameter"		: {"property": "property", "default": "Default"},
		"id" : {"property" : "id", "default": ""},
		"method" : {"property" : "method", "default": "Place"},
		"depth" : {"property" : "depth", "default": "Closefront"},
		"start" : {"property" : "start", "default": 0.0},
		"end" : {"property" : "end", "default": 0.0},
		"flipped" : {"property" : "flipped", "default": false}
	}

# You can alternatively overwrite these 3 functions: to_text(), from_text(), is_valid_event()
#endregion


#region EDITOR REPRESENTATION
################################################################################

func build_event_editor() -> void:
	pass

#endregion
