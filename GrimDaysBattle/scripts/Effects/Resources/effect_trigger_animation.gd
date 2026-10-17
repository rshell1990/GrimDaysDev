extends EffectTemplate
## Implements the runtime effect template trigger animation behavior used by the battle effect pipeline.
class_name EffectTemplateTriggerAnimation

@export_group("Animation Details")
## Configures the animation id used by this effect template trigger animation.
@export var animation_id: StringName
## Whether this animation is intended for Spine playback.
@export var use_spine: bool = false
## Whether this animation should repeat.
@export var loop: bool = false
## Spine animation track used for this animation.
@export var track_number: int = 0
