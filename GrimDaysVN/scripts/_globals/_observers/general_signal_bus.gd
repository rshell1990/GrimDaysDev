extends Node

## Notification for on ui update.
signal on_ui_update
## Notification for on load. Supplies [code]data[/code] to connected functions.
signal on_load(data)
## Notification for on side character set. Supplies [code]character[/code] to connected functions.
signal on_side_character_set(character: CharacterOperator)
## Notification for on tooltip show. Supplies [code]header_text[/code],
## [code]description_text[/code] to connected functions.
signal on_tooltip_show(header_text: String, description_text: String)
## Notification for on tooltip hide.
signal on_tooltip_hide
## Notification for bind inventory. Supplies [code]ui[/code] to connected functions.
signal bind_inventory(ui)
## Notification for item used. Supplies [code]id[/code] to connected functions.
signal item_used(id: int)
## Notification for time distorted. Supplies [code]state[/code], [code]amount[/code] to connected
## functions.
signal time_distorted(state: bool, amount: float)
## Notification for state changed. Supplies [code]new_state[/code] to connected functions.
signal state_changed(new_state: GameManagerStates.STATES)
## Notification for music played.
signal music_played
## Notification for ovani music played.
signal ovani_music_played
## Notification for day passed. Supplies [code]old_day[/code] to connected functions.
signal day_passed(old_day: Time.Weekday)
## Notification for day updated.
signal day_updated
## Notification for time passed. Supplies [code]old_time[/code], [code]new_time[/code] to connected
## functions.
signal time_passed(old_time: TimeAdministrator.TIMES, new_time: TimeAdministrator.TIMES)
## Notification for location changed. Supplies [code]new_locationStringName[/code] to connected
## functions.
signal location_changed(new_locationStringName)
## Notification for dimension changed. Supplies [code]new_dimension[/code] to connected functions.
signal dimension_changed(new_dimension: NavigationAdministrator.DIMENSIONS)
## Notification for show history.
signal show_history

## Notification for end state.
signal end_state

## Notification for main camera entered. Supplies [code]camera[/code] to connected functions.
signal main_camera_entered(camera: MainCameraOperator)
## Notification for event found. Supplies [code]event[/code] to connected functions.
signal event_found(event)
## Notification for play animation. Supplies [code]animation_name[/code] to connected functions.
signal play_animation(animation_name: String)

## Notification for font scale changed. Supplies [code]new_scale[/code] to connected functions.
signal font_scale_changed(new_scale: float)
## Notification for primary font changed. Supplies [code]new_font[/code] to connected functions.
signal primary_font_changed(new_font: String)
## Notification for secondary font changed. Supplies [code]new_font[/code] to connected functions.
signal secondary_font_changed(new_font: String)
## Notification for tertiary font changed. Supplies [code]new_font[/code] to connected functions.
signal tertiary_font_changed(new_font: String)

## Notification for clear rollback.
signal clear_rollback
## Notification for loading sequence start.
signal loading_sequence_start
## Notification for reset sub systems.
signal reset_sub_systems


## Forwards the supplied event as [signal show_history] so connected systems can respond.
func on_show_history() -> void:
    show_history.emit()


## Forwards the supplied event as [signal primary_font_changed] so connected systems can respond.
func _on_primary_font_changed(new_font: String) -> void:
    primary_font_changed.emit(new_font)


## Forwards the supplied event as [signal secondary_font_changed] so connected systems can respond.
func _on_secondary_font_changed(new_font: String) -> void:
    secondary_font_changed.emit(new_font)


## Forwards the supplied event as [signal tertiary_font_changed] so connected systems can respond.
func _on_tertiary_font_changed(new_font: String) -> void:
    tertiary_font_changed.emit(new_font)


## Forwards the supplied event as [signal font_scale_changed] so connected systems can respond.
func _on_font_scale_changed(new_scale: float) -> void:
    font_scale_changed.emit(new_scale)


## Forwards the supplied event as [signal ovani_music_played] so connected systems can respond.
func _on_ovani_music_played() -> void:
    ovani_music_played.emit()


## Forwards the supplied event as [signal music_played] so connected systems can respond.
func _on_music_played() -> void:
    music_played.emit()


## Forwards the supplied event as [signal bind_inventory] so connected systems can respond.
func _on_inventory_bind_request(ui) -> void:
    bind_inventory.emit(ui)


## Forwards the supplied event as [signal on_ui_update] so connected systems can respond.
func _on_ui_update() -> void:
    on_ui_update.emit()


## Forwards the supplied event as [signal on_load] so connected systems can respond.
func _on_load(data) -> void:
    on_load.emit(data)


## Forwards the supplied event as [signal item_used] so connected systems can respond.
func _on_item_used(id: Variant) -> void:
    if not id:
        return
    item_used.emit(id)


## Forwards the supplied event as [signal time_distorted] so connected systems can respond.
func _on_time_changed(state: bool, amount: float) -> void:
    time_distorted.emit(state, amount)


# func _on_item_effect_activation(id:int) -> void:
# 	var item = Repositories.get_info(RepositoryTypes.ITEMS, id)
# 	var positive_effects = item.positive_effects
# 	var negative_effects = item.negative_effects

# 	for positive_effect in positive_effects:
# 		positive_effect.kind = EffectBase.KIND.POSITIVE
# 		if positive_effect.target == EffectBase.TARGET.PLAYER:
# 			player_bus._on_sent_effect(positive_effect)
# 		else:
# 			enemy_bus._on_sent_effect(positive_effect)

# 	for negative_effect in negative_effects:
# 		negative_effect.kind = EffectBase.KIND.NEGATIVE
# 		if negative_effect.target == EffectBase.TARGET.PLAYER:
# 			player_bus._on_sent_effect(negative_effect)
# 		else:
# 			enemy_bus._on_sent_effect(negative_effect)


## Forwards the supplied event as [signal on_side_character_set] so connected systems can respond.
func _on_side_character_set(character) -> void:
    if get_node_or_null("/root/DialogicLayout_DefaultVnStyle") == null:
        await Dialogic.Text.about_to_show_text
    on_side_character_set.emit(character)


## Forwards the supplied event as [signal on_tooltip_show] so connected systems can respond.
func _on_tooltip_show(header_text: Variant, description_text: Variant) -> void:
    if not header_text and not description_text:
        return
    on_tooltip_show.emit(header_text, description_text)


## Forwards the supplied event as [signal on_tooltip_hide] so connected systems can respond.
func _on_tooltip_hide() -> void:
    on_tooltip_hide.emit()


## Forwards the supplied event as [signal time_passed] so connected systems can respond.
func on_time_change(old_time: TimeAdministrator.TIMES, new_time: TimeAdministrator.TIMES) -> void:
    on_tooltip_hide.emit()
    time_passed.emit(old_time, new_time)


## Forwards the supplied event as [signal day_passed] so connected systems can respond.
func on_day_passed() -> void:
    on_tooltip_hide.emit()
    day_passed.emit(SystemAdministrators.time_admin.current_day_id())


## Forwards the supplied event as [signal day_updated] so connected systems can respond.
func on_day_updated() -> void:
    on_tooltip_hide.emit()
    day_updated.emit()


## Forwards the supplied event as [signal state_changed] so connected systems can respond.
func on_state_change(new_state: GameManagerStates.STATES) -> void:
    on_tooltip_hide.emit()
    state_changed.emit(new_state)


## Forwards the supplied event as [signal location_changed] so connected systems can respond.
func on_location_changed(new_location: StringName) -> void:
    on_tooltip_hide.emit()
    location_changed.emit(new_location)


## Forwards the supplied event as [signal dimension_changed] so connected systems can respond.
func on_dimension_changed(new_dimension: NavigationAdministrator.DIMENSIONS) -> void:
    dimension_changed.emit(new_dimension)


## Connects the supplied notification to its response function, using the connection checks in this
## helper.
func listen_for(sent_signal: Signal, run_when_signaled: Callable) -> void:
    if sent_signal.is_connected(run_when_signaled):
        return
    sent_signal.connect(run_when_signaled)
