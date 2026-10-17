extends Control
## Controls the floating text controller presentation used by the battle interface.
class_name FloatingTextController

## Configures the dodge label template used by this floating text controller.
@export var dodge_label_template: Label
## Configures the damaged label template used by this floating text controller.
@export var damaged_label_template: Label
## Configures the healed label template used by this floating text controller.
@export var healed_label_template: Label


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    var display := get_parent().get_parent() as Unit2DDisplay
    if display and not display.use_global_battle_navigation:
        return
    SignalBus.damaged.connect(on_damaged)
    SignalBus.dodged.connect(on_dodge)
    SignalBus.healed.connect(on_healed)


## Handles the dodge notification for this floating text controller.
func on_dodge(unit: BattleUnit) -> void:
    var parent: Unit2DDisplay = get_parent().get_parent()
    if parent.unit_reference != unit:
        return

    var duplicate_label: Label = dodge_label_template.duplicate()
    add_child(duplicate_label)
    duplicate_label.visible = true
    var label_animator: AnimationPlayer = duplicate_label.get_child(0)
    label_animator.play("start")
    label_animator.advance(0)


## Production feedback is driven by ordered encounter events, never broadcasts.
func present_event(event: BattleCombatEvent) -> void:
    match event.type:
        BattleCombatEvent.TYPE.DAMAGE:
            on_damaged(event.target, roundi(event.amount))
        BattleCombatEvent.TYPE.HEALING:
            on_healed(event.target, roundi(event.amount))
        BattleCombatEvent.TYPE.MISS:
            on_dodge(event.target)
        BattleCombatEvent.TYPE.CRITICAL, BattleCombatEvent.TYPE.REVIVED:
            var label := healed_label_template.duplicate() as Label
            label.text = "Critical!" if event.type == BattleCombatEvent.TYPE.CRITICAL else "Revived"
            add_child(label)
            label.show()
            var animator := label.get_child(0) as AnimationPlayer
            animator.play("start")
            animator.advance(0)


## Handles the damaged notification for this floating text controller.
func on_damaged(unit: BattleUnit, amount: int) -> void:
    var parent: Unit2DDisplay = get_parent().get_parent()
    if parent.unit_reference != unit:
        return

    var duplicate_label: Label = damaged_label_template.duplicate()
    duplicate_label.text = "- " + str(amount)
    add_child(duplicate_label)
    duplicate_label.visible = true
    var label_animator: AnimationPlayer = duplicate_label.get_child(0)
    label_animator.play("start")
    label_animator.advance(0)


## Handles the healed notification for this floating text controller.
func on_healed(unit: BattleUnit, amount: int) -> void:
    var parent: Unit2DDisplay = get_parent().get_parent()
    if parent.unit_reference != unit:
        return

    var duplicate_label: Label = healed_label_template.duplicate()
    duplicate_label.text = "+ " + str(amount)
    add_child(duplicate_label)
    duplicate_label.visible = true
    var label_animator: AnimationPlayer = duplicate_label.get_child(0)
    label_animator.play("start")
    label_animator.advance(0)
