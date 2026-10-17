extends RefCounted
## Restricted full-reset entry point. A real, currently executing authored
## Dialogic Call is the authority, not a UI boolean or a general preparation lease.
## Future paid vendor/item routes must validate/consume their own authority before
## invoking the unit primitive; they must not reuse this story route.
class_name BattleSkillResetService


## Supported authoring: do UIDirector.reset_story_skill_trees("unit_id")
## Use a literal unit ID. Returns refunded ranks, or -1 when not authorized.
static func reset_from_story(party: BattlePartyManager, unit_id: StringName) -> int:
    if (
        not is_instance_valid(party)
        or not party.can_prepare_inventory()
        or (party._preparation_owner and is_instance_valid(party._preparation_owner.get_ref()))
        or GameManager.state not in BattlePreparationSession.STORY_STATES
        or not Dialogic.current_timeline
        or Dialogic.paused
        or SceneManager.swapping
        or SaveAndLoadSystemManager.restoring_data
        or SaveAndLoadSystemManager._operation_in_progress
    ):
        return -1
    var event: Variant = Dialogic.get_meta(&"previous_event", null)
    var index: int = Dialogic.current_event_idx
    if (
        event is not DialogicCallEvent
        or event.autoload_name != "UIDirector"
        or event.method != "reset_story_skill_trees"
        or event.arguments != [String(unit_id)]
        or not event.event_finished.is_connected(Dialogic.handle_next_event)
        or index < 0
        or index >= Dialogic.current_timeline_events.size()
        or Dialogic.current_timeline_events[index] != event
    ):
        return -1
    var unit: BattleUnit = party.runtime_units.get(unit_id)
    if not is_instance_valid(unit) or not unit.skills:
        return -1
    return unit.skills.reset_all_from_authorized_source(unit.skills.revision)
