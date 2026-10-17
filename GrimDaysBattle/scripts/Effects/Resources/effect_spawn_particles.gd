extends EffectTemplate
## Authored particle scene and cleanup settings for a battle effect.
class_name EffectSpawnParticlesTemplate

## Scene instantiated by the target's presentation. AnimatedSprite2D and
## one-shot particle nodes clean themselves up when their animation finishes.
@export var particle_scene: PackedScene
## Added to the root's authored local position only when animation_name is empty.
@export var starting_offset: Vector2 = Vector2.ZERO
## Production resolution delay, and fallback cleanup time without a completion signal.
@export_range(0.0, 60.0, 0.1, "or_greater") var lifetime_seconds: float = 2.0

@export_group("Animation Details")
## Optional animation on a scene-unique AnimationPlayer named Animator.
## Its completion owns cleanup, regardless of the particle scene's root type.
@export var animation_name: StringName = &""
