extends Resource

## Information about an individual spine animation. These resources are used to assign what
## animations are available to a particular spine character.
## Authored spine animation data used by this system.
class_name CharacterAnimationInfo

## The animation's generic name.
@export var called: String

## The animation's internal name.
@export var animation_name: String

## If the animation should loop or just run once.
@export var will_loop: bool

## Tracks are used to separate the various parts of a spine character than can be simultaneously
## animated. If an animation is playing on the track referenced when setting the animation it will
## replace that animation.
@export var track: int
