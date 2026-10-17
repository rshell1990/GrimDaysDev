extends EquipmentTemplate
## Coordinates equipment weapon template behavior for the battle system.
class_name EquipmentWeaponTemplate

## Gameplay categories used by action requirements, for example bladed.
@export var weapon_tags: Array[StringName] = []

## The action used by the wielder while this weapon is equipped.
@export var basic_action_template: ActionTemplate

## Legacy numeric fields retained for existing authored data. New weapons should
## express their behavior through effects and [member basic_action_template].
@export var base_attack: int
## Configures the base accuracy used by this equipment weapon template.
@export var base_accuracy: int
