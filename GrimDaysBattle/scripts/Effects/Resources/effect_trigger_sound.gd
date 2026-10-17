extends EffectTemplate
## Authored sound playback settings for a battle effect.
class_name EffectTriggerSoundTemplate

## Configures the sound used by this effect trigger sound.
@export var sound: AudioStream
## Configures the volume db used by this effect trigger sound.
@export_range(-80.0, 24.0, 0.1) var volume_db: float = 0.0
## Configures the pitch scale used by this effect trigger sound.
@export_range(0.01, 4.0, 0.01) var pitch_scale: float = 1.0
