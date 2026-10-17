extends Node
## Forwards unit-related requests such as healing, resource changes and effects to connected
## listeners.
class_name VNEntitySignalBus

## Notification for receive healing. Supplies [code]amount[/code] to connected functions.
signal receive_healing(amount: int)
## Notification for receive percentage healing. Supplies [code]amount[/code] to connected functions.
signal receive_percentage_healing(amount: float)
## Notification for sent effects. Supplies [code]incoming[/code] to connected functions.
signal sent_effects(incoming: Array)
# signal take_damage(amount:int, charge:int, hit_type:CollisionZones.KINDS)
# signal take_percentage_damage(amount:float, charge:int, hit_type:CollisionZones.KINDS)
## Notification for lower power. Supplies [code]amount[/code] to connected functions.
signal lower_power(amount: float)
## Notification for raise power. Supplies [code]amount[/code] to connected functions.
signal raise_power(amount: float)
## Notification for lower charge. Supplies [code]amount[/code] to connected functions.
signal lower_charge(amount: float)
## Notification for raise charge. Supplies [code]amount[/code] to connected functions.
signal raise_charge(amount: float)
## Notification for emit particle. Supplies [code]particle[/code] to connected functions.
signal emit_particle(particle: PackedScene)


## Forwards the supplied event as [signal lower_charge] so connected systems can respond.
func _on_charge_lowered(amount: float) -> void:
    lower_charge.emit(amount)


## Forwards the supplied event as [signal raise_charge] so connected systems can respond.
func _on_charge_raised(amount: float) -> void:
    raise_charge.emit(amount)


## Forwards the supplied event as [signal lower_power] so connected systems can respond.
func _on_power_lowered(amount: float) -> void:
    lower_power.emit(amount)


## Forwards the supplied event as [signal raise_power], [signal take_damage], [signal
## take_percentage_damage] so connected systems can respond.
func _on_power_raised(amount: float) -> void:
    raise_power.emit(amount)


# func _on_sent_damage(amount:int, charge:int, hit_type:CollisionZones.KINDS) -> void:
# 	take_damage.emit(amount, charge, hit_type)

# func _on_sent_percentage_damage(amount:float, charge:int, hit_type:CollisionZones.KINDS) -> void:
# 	take_percentage_damage.emit(amount, charge, hit_type)


## Forwards the supplied event as [signal receive_healing] so connected systems can respond.
func _on_sent_healing(amount: int) -> void:
    receive_healing.emit(amount)


## Forwards the supplied event as [signal receive_percentage_healing] so connected systems can
## respond.
func _on_sent_percentage_healing(amount: float) -> void:
    receive_percentage_healing.emit(amount)


## Forwards the supplied event as [signal sent_effects] so connected systems can respond.
func _on_sent_effect(incoming: EffectBase) -> void:
    sent_effects.emit(incoming)


## Forwards the supplied event as [signal emit_particle] so connected systems can respond.
func _on_sent_particle(incoming: PackedScene) -> void:
    emit_particle.emit(incoming)


## Connects the supplied notification to its response function, using the connection checks in this
## helper.
func listen_for(sent_signal: Signal, run_when_signaled: Callable) -> void:
    if sent_signal.is_connected(run_when_signaled):
        return
    sent_signal.connect(run_when_signaled)
