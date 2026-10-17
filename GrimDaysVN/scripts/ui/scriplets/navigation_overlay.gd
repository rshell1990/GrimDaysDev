extends LoadableControl
## This script controls the general navigation UI. It will hide itself when Dialogic timelines are started, and will
## restore it's visibility when those timelines
## end.   It updates the day, week, location, and money labels in response to signals from the Signal Bus.

## Scene object used for day label.
@export var day_label: Label
## Scene object used for week label.
@export var week_label: Label
## Scene object used for location label.
@export var location_label: Label
## Scene object used for money label.
@export var money_label: Label

## Button used for settings button.
@export var settings_button: Button
## Button used for phone button.
@export var phone_button: Button
## Button used for inventory button.
@export var inventory_button: Button
## Scene object used for time display.
@export var time_display: Control


## When the node is ready, this function connects responses to [code]VNSignalBus.day_updated[/code],
## [code]VNSignalBus.location_changed[/code], [code]SystemAdministrators.ready[/code],
## [code]settings_button.button_up[/code].
func _ready() -> void:
    VNSignalBus.day_updated.connect(on_day_updated)
    VNSignalBus.location_changed.connect(on_location_changed)
    SystemAdministrators.ready.connect(on_system_admins_ready)
    settings_button.button_up.connect(on_settings_button_up)
    phone_button.button_up.connect(on_phone_button_up)
    inventory_button.button_up.connect(on_inventory_button_up)
    #money_label.text = "$ " + str(snappedf(SystemHelpers.get_player().money, 0.01))


## Shows navigation controls only while the active game mode is Navigation.
@warning_ignore("unused_parameter")
func _physics_process(delta: float) -> void:
    if GameManager.state_manager.current_state.id == GameManagerStates.STATES.Navigation:
        if not visible:
            SystemHelpers.print(self.name, ": SHOWING.")
            show()
    else:
        if visible:
            SystemHelpers.print(self.name, ": HIDING.")
            hide()


## Connects responses to [code]SystemAdministrators.time_admin.ready[/code].
func on_system_admins_ready() -> void:
    SystemHelpers.print("System Admin Ready")
    if not SystemAdministrators.time_admin.ready:
        SystemHelpers.print("Connecting to admin.")
        SystemAdministrators.time_admin.ready.connect(on_time_admin_ready)
        return
    on_time_admin_ready()


## Updates [code]day_label.text[/code] using [code]SystemAdministrators.date_string[/code]; updates
## [code]week_label.text[/code] using [code]SystemAdministrators.get_day_name[/code]; updates
## [code]location_label.text[/code] using [code]SystemAdministrators.get_location_as_string[/code].
func on_time_admin_ready() -> void:
    day_label.text = SystemAdministrators.date_string()
    week_label.text = SystemAdministrators.get_day_name(SystemAdministrators.current_day())
    location_label.text = SystemAdministrators.get_location_as_string(SystemAdministrators.current_location())


## Updates [code]day_label.text[/code] using [code]SystemAdministrators.current_day[/code]; updates
## [code]week_label.text[/code] using [code]SystemAdministrators.get_day_name[/code].
func on_day_updated() -> void:
    day_label.text = SystemAdministrators.current_day().to_string()
    week_label.text = SystemAdministrators.get_day_name(SystemAdministrators.current_day())


## Updates [code]location_label.text[/code] using
## [code]SystemAdministrators.get_location_as_string[/code]; sets [code]money_label.text[/code] to
## [code]"$ " + str(snappedf(SystemHelpers.get_player().money, 0.01))[/code].
func on_location_changed(new_location) -> void:
    location_label.text = SystemAdministrators.get_location_as_string(new_location)
    money_label.text = "$ " + str(snappedf(SystemHelpers.get_player().money, 0.01))


## Forwards the restored time of day to the navigation time display.
func on_restore(_old_time: TimeAdministrator.TIMES, new_time: TimeAdministrator.TIMES) -> void:
    time_display.on_time_passed(_old_time, new_time)


## Opens the settings menu from the navigation overlay.
func on_settings_button_up() -> void:
    UIDirector.visible = false
    await RenderingServer.frame_post_draw
    Dialogic.Save.take_thumbnail()
    await RenderingServer.frame_post_draw
    UIDirector.visible = true
    UIDirector.show_settings_menu()


## Shows the phone only after the world-stage number reaches 20.
func on_phone_button_up() -> void:
    if GameManager.world_stage < 20:
        return
    UIDirector.show_phone()


## Navigation is the only freely available preparation entry point.
func on_inventory_button_up() -> void:
    UIDirector.show_party_preparation()


## Hides the inventory cover when its close button is released.
func _on_inventory_close_button_up() -> void:
    %"Inventory Cover".visible = false
