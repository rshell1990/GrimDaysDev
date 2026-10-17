extends Object
## Coordinates combat behavior for the battle system.
class_name Combat

#region BATTLE
## Enumerates the supported battle states values.
enum BATTLE_STATES {
    ## Initial State, select in the debug arena is to actually pick the targets. In the full game it will be to insert
    ## the current party and then either use the supplied targets for bespoke fights or generate enemies from templates
    ## for random encounters.
    SELECT_PARTICIPANTS = 0,
    ## Intialize the view (what the player sees) and the data (what the underlying code relys on) if necessary for each
    ## participant.
    INITIALIZE_BATTLEFIELD = 100,
    ## Create a starting turn order, will sort all units on the battlefield by speed in the main game, in the debug
    ## arena
    ## will just go back and forth from the allies to foes untill all units have been added.
    INITIALIZE_TURN_ORDER = 200,
    ## Starts a new round of combat.
    ROUND_START = 300,
    ## Get the next unit from the turn order, if the round has just started it gets the first unit in the turn order.
    ## Otherwise it removes the first unit and then if there is a unit still in the turn order it becomes active.
    GET_ACTIVE_UNIT = 400,
    ## If the active unit is player controlled, the UI to perform an action is made visible and will remain in this
    ## phase
    ## untill an action is selected.
    GIVE_PLAYER_CONTROL = 500,
    ## If the active unit is ai controlled, the controlling ai will decided which action to take.
    GIVE_AI_CONTROL = 600,
    ## Waits for the player to select an action from the now visible UI.
    GET_ACTION_FROM_PLAYER = 700,
    ## The configured AI will decide what action to take.
    GET_ACTION_FROM_AI = 800,
    ## If the action requires the ai/player to choose targets, this phase is set active.
    GET_COMBAT_TARGETS = 900,
    ## If the action has predefined targets, then they will be set during this phase.
    SET_COMBAT_TARGETS = 1000,
    ## Resolve the selected action once through the deterministic domain resolver.
    RESOLVE_ACTION = 1050,
    ## Give room for effects that can change the outcome of a hit for the active unit.
    PROCESS_ACTIVE_BEFORE_HIT = 1100,
    ## Give room for effects that can change the outcome of a hit for the targetted unit.
    PROCESS_TARGET_CHECK_BEFORE_HIT = 1110,
    ## Check if target needs to change before hit.
    PROCESS_CHANGE_TARGET = 1115,
    ## Check if the target is hit.
    PROCESS_TARGET_CHECK_FOR_HIT = 1120,
    ## Process effects that occur when the target is hit.
    PROCESS_TARGET_HIT = 1130,
    ## Process effects that occur on the active unit after they successfully hit.
    PROCESS_ACTIVE_AFTER_HIT = 1140,
    ## Process effects on the target that occur after they have been hit.
    PROCESS_TARGET_AFTER_HIT = 1150,
    ## Process that checks if units have been defeated.
    PROCESS_CHECK_FOR_DEFEATED = 2000,
    ## Process that checks if units have been defeated.
    PROCESS_UPDATE_TURN_ORDER = 2500,
    ## If the target is defeated, trigger on defeat effects on the target.
    PROCESS_DEFEAT = 1160,
    ## If the active unit has killed the target, and is still active. Then trigger on kill effects for the active unit.
    PROCESS_KILL = 1190,
    # ## Process that checks if units have been defeated.
    # PROCESS_CHECK_FOR_DEFEATED = 2000,
    # ## Process that checks if units have been defeated.
    # PROCESS_UPDATE_TURN_ORDER = 2500,
    ## Process effects that occur after the action has been activated once. This may continue to get the next unit or
    ## return to an earlier phase.
    PROCESS_ACTIVE_ACTION_FINISHED = 1200,
    ## Checks for the next target to apply the action to, if there are additional targets return to
    ## PROCESS_TARGET_CHECK_BEFORE_HIT else go to PROCESS_TARGET_ACTION_FINISHED.
    PROCESS_CHECK_FOR_NEXT_TARGET = 3000,
    ## Once everything is about to end, trigger effects on targets that trigger at ROUND_END.
    TRIGGER_ROUND_END_EFFECTS = 5000,
    # ## Process that checks if units have been defeated.
    # PROCESS_CHECK_FOR_DEFEATED = 2000,
    # ## Process that checks if units have been defeated.
    END_ROUND = 5500,
    ## When every unit in 'Foes' is defeated, this phase will begin.
    VICTORY = 10000,
    ## When eveyr unit in 'Allies' is defeated, this phase will begin.
    DEFEAT = 20000
}


## Adds effects from category for this combat.
static func add_effects_from_category(
    selected_action: ActionTemplate,
    active_unit: BattleUnit,
    first_target: BattleUnit,
    trigger: CombatEffects.TRIGGER,
    context: Dictionary = {},
) -> int:
    if not selected_action or not active_unit or not first_target:
        return 0
    if not selected_action.has_method("get_effects_by_rank_and_trigger"):
        return 0
    var action_effects: Array = selected_action.get_effects_by_rank_and_trigger(
        active_unit.get_action_rank(selected_action), trigger
    )
    if action_effects.is_empty():
        return 0
    var added_count: int
    for effect in action_effects:
        if not effect:
            continue
        var effect_targets = CombatActions.get_effect_target(active_unit, first_target, effect)
        (
            CustomLogger
            . hint(
                Combat,
                add_effects_from_category,
                "Effect %s targets: %s" % [effect, effect_targets],
                CustomLogger.LEVEL.VERY_VERBOSE,
            )
        )
        for target in effect_targets:
            if not is_instance_valid(target):
                continue
            target.add_effect(active_unit, target, effect, context)
            added_count += 1
    return added_count

#endregion
