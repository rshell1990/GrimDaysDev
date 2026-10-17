extends AudioStreamPlayer3D
class_name AudioStreamFader3D


## When the node is ready, this function connects responses to [code]owner.tree_exiting[/code].
func _ready() -> void:
    owner.tree_exiting.connect(fade_out)


## Smoothly changes [code]volume_db[/code] over time.
func fade_out() -> void:
    var tween = create_tween()
    tween.tween_property(self, "volume_db", -80.0, VNAnimationTimes.FAST)
