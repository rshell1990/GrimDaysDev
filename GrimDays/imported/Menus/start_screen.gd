## Start-screen Control shell. The example version label and menu callbacks below are commented
## out; this script declares no active behavior.

class_name StartScreen extends Control

# const template_version: String = "0.1"

# # These 4 lines are not covered in the initial video.
# # They've been added here just to make it easier for you
# # to differentiate versions. I had not intended to provide updates so this
# # feature was skipped in original code.
# @onready var version_num: Label = %VersionNum
# func _ready() -> void:
# 	version_num.text = "v%s" % template_version

# func _on_start_button_up() -> void:
# 	SceneManager.swap_scenes( self, Repositories.kinds.SystemScenes["world"],
# 		get_tree().root, self, "fade_to_black" )

# func _on_settings_button_up() -> void:
# 	SM_Globals.open_settings_menu()

# func _on_quit_button_up() -> void:
# 	SM_Globals.quit()
