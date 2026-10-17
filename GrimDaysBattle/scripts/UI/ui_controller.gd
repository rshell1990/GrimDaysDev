# Editor configuration for BattleUIController.
@tool
extends Control
## Controls the battle uicontroller presentation used by the battle interface.
class_name BattleUIController


## Handles the phantom camera 2d became inactive notification for this uicontroller.
func _on_phantom_camera_2d_became_inactive() -> void:
    #var tween = create_tween()
    #tween.tween_property(self, "modulate:a",0.0,AnimationTimes.FAST)
    pass


## Handles the phantom camera 2d became active notification for this uicontroller.
func _on_phantom_camera_2d_became_active() -> void:
    var tween = create_tween()
    tween.tween_property(self, "modulate:a", 1.0, AnimationTimes.FAST)
