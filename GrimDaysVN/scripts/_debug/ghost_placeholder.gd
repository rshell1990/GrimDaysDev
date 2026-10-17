## Inactive ghost-combat prototype retained as commented reference. No signals, callbacks or
## runtime behavior are currently declared.

#extends Sprite2D
#
#signal completed_death()
#
#@export var animator:AnimationPlayer
#@export_category("Audio Cues")
#@export var bad_damage:String
#@export var good_damage:String
#@export var great_damage:String
#@export var perfect_damage:String
#var parent:Node
#
#func _ready():
#VNSignalBus.enemy_bus.take_damage.connect(on_took_damage)
#animator.play("RESET")
#
#func on_death():
#await animator.animation_finished
#animator.play(BattleConstants.DEATH)
#await animator.animation_finished
#completed_death.emit()
#
#func on_took_damage(_damage, _charge, hit_type):
#match hit_type:
#0:
#SoundManager.play_sound(Repositories.get_info(RepositoryTypes.SOUNDS, bad_damage))
#animator.play(BattleConstants.BAD_HIT)
#1:
#SoundManager.play_sound(Repositories.get_info(RepositoryTypes.SOUNDS, good_damage))
#animator.play(BattleConstants.OKAY_HIT)
#2:
#SoundManager.play_sound(Repositories.get_info(RepositoryTypes.SOUNDS, great_damage))
#animator.play(BattleConstants.GREAT_HIT)
#3:
#SoundManager.play_sound(Repositories.get_info(RepositoryTypes.SOUNDS, perfect_damage))
#animator.play(BattleConstants.PERFECT_HIT)
