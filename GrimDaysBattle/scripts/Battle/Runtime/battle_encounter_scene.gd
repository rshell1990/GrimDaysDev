extends Node
## Connects the battle manager, turn handling, displays and retry controls.
## The story supplies opponent templates and the player's existing party manager.
class_name BattleEncounterScene

## Announces the result of one attempt, including results that still require a retry.
signal battle_finished(result: BattleResult)
## Accepted result, distinct from a failed attempt waiting for retry.
signal encounter_completed(result: BattleResult)
## Announces that this battle attempt needs a retry. Supplies the coordinator’s session_id, not the
## number of attempts.
signal retry_required(attempt: int)

## Child node that starts and ends each attempt and keeps its units and result.
@onready var coordinator: BattleCoordinator = $Coordinator
## Child node that connects each battle unit to its on-screen display.
@onready var stage: BattleVisualStage = $VisualStage
## Child that advances turns and routes player and AI actions.
@onready var flow: BattleEncounterFlow = $Flow
## Most recent encounter startup or session failure message.
var last_error: String = ""
## Number of attempts started in this session, including the initial attempt.
var attempts: int = 0
## Whether a completed attempt is waiting for explicit player retry input.
var awaiting_retry: bool = false
## Victory is complete but rewards await the player's shared-inventory choices.
var awaiting_reward_choices: bool = false
## Capacity-resolution overlay for pending victory loot.
var reward_inventory: BattleRewardInventory
## Rewards/recovery are committed; only the player's acknowledgement is pending.
var awaiting_continue: bool = false
## Terminal result display shown before the player continues the story.
var result_summary: BattleResultSummary
## Result retained after acceptance for the deferred completion handoff.
var _accepted_result: BattleResult
## Stat/reward observers may call back synchronously while settlement is running.
var _settling_result: bool = false
## Whether defeat must offer a retry instead of completing the session; draws always retry.
var _require_victory: bool = false
## Active through combat, retries, reward choices and result acknowledgement.
var _session_active: bool = false
## Existing player party manager used again on every retry.
var _party: BattlePartyManager
## Copied opponent template list used to construct each attempt's foes.
var _foes: Array[BattleUnitTemplate]
## Stable encounter identifier shared by all attempts in the session.
var _encounter_id: StringName
## Starting number for random choices, reused on retry so the same choices can produce the same
## results.
var _seed: int
## Information from the system that started the battle, copied with its nested lists and
## dictionaries into each attempt's result.
var _context: Dictionary
## Reward settings copied with their nested lists and dictionaries for each attempt.
var _rewards: Dictionary
## Party state remembered before the first attempt, so a retry can undo changes made during battle.
var _checkpoint := BattleRetryCheckpoint.new()


## Connects battle-end and retry notifications, and joins the group checked before allowing saves.
func _ready() -> void:
    coordinator.battle_finished.connect(func(_token: int, result: BattleResult): battle_finished.emit(result))
    coordinator.battle_finished.connect(_on_attempt_finished)
    $Interface/ActionMenu.retry_requested.connect(retry_encounter)
    reward_inventory = BattleRewardInventory.new()
    $Interface.add_child(reward_inventory)
    reward_inventory.discard_stored.connect(_discard_stored_reward_item)
    reward_inventory.decline_reward.connect(_decline_reward_item)
    reward_inventory.collect_requested.connect(collect_rewards)
    result_summary = BattleResultSummary.new()
    $Interface.add_child(result_summary)
    result_summary.continue_requested.connect(continue_encounter)
    add_to_group(&"battle_save_guards")


## Starts a battle with support for retries. The story or another game system can call this.
## Announces the accepted result through encounter_completed after player Continue.
func begin_session(
    party: BattlePartyManager,
    foes: Array[BattleUnitTemplate],
    encounter_id: StringName,
    battle_seed: int = 0,
    return_context: Dictionary = {},
    rewards: Dictionary = {},
    require_victory: bool = false
) -> bool:
    if _session_active or coordinator.state != BattleCoordinator.STATE.IDLE:
        return false
    _party = party
    $Interface/ActionMenu.show()
    _foes = foes.duplicate()
    _encounter_id = encounter_id
    _seed = battle_seed
    _context = return_context.duplicate(true)
    _rewards = rewards.duplicate(true)
    _require_victory = require_victory
    if not is_instance_valid(party):
        return false
    _checkpoint.capture(party.get_active_party())
    _session_active = true
    attempts = 1
    if not begin_encounter(party, _foes, encounter_id, battle_seed, _context, _rewards):
        _session_active = false
        return false
    return true


## Schedules the retry-or-finish decision for after all listeners receive the battle result.
func _on_attempt_finished(token: int, result: BattleResult) -> void:
    if _session_active:
        _finish_attempt.call_deferred(token, result)


## Ignores results from old attempts, offers a retry when required, or announces the accepted
## result.
func _finish_attempt(token: int, result: BattleResult) -> void:
    if (
        not _session_active
        or token != coordinator.session_id
        or coordinator.current_result != result
        or awaiting_retry
        or _settling_result
    ):
        return
    if result.outcome == BattleResult.OUTCOME.DRAW or (_require_victory and result.is_defeat()):
        # Keep the party lease and save guard until the player explicitly retries.
        awaiting_retry = true
        $Interface/ActionMenu.show_retry(token)
        retry_required.emit(token)
        return
    if result.is_victory() or result.is_defeat():
        _settling_result = true
        var errors := BattleRewardSettlement.apply(result, _party, coordinator.roster.get_allies())
        if not _session_active or token != coordinator.session_id or coordinator.current_result != result:
            _settling_result = false
            return  # A synchronous observer cancelled/replaced the encounter.
        if not errors.is_empty():
            _settling_result = false
            last_error = "Reward settlement failed: %s" % "; ".join(errors)
            $Interface/ActionMenu.show_error(last_error)
            if result.reward_capacity_blocked:
                awaiting_reward_choices = true
                $Interface/ActionMenu.hide()
                reward_inventory.present(_party.stash, result, token)
            else:
                awaiting_reward_choices = false
                reward_inventory.hide()
                $Interface/ActionMenu.show()
            return  # Retain the party lease/foes and do not continue the story unpaid.
        awaiting_reward_choices = false
        reward_inventory.hide()
        last_error = ""
        BattlePartyRecovery.apply(result, coordinator.roster.get_allies())
        if not _session_active or token != coordinator.session_id or coordinator.current_result != result:
            _settling_result = false
            return
        coordinator.cleanup(token)  # Rewards and snapshots are safe; release foe nodes.
        _settling_result = false
        if not _session_active or token != coordinator.session_id:
            return  # A battle-clearing observer cancelled the result handoff.
        # Keep the persistent party reserved while its caller waits for Continue.
        # Roster cleanup released the combat lease and restored affiliation first.
        if not _party.acquire_encounter(self):
            _fail_session("The party became unavailable during the result handoff.")
            return
        _accepted_result = result
        awaiting_continue = true
        $Interface/ActionMenu.hide()
        result_summary.present(result, token)
        return
    _session_active = false
    if result.outcome == BattleResult.OUTCOME.ERROR:
        last_error = result.error
        $Interface/ActionMenu.show_error(last_error)
    encounter_completed.emit(result)


## Acknowledges an already-settled result exactly once. Does not repeat rewards,
## recovery or cleanup, and cannot continue a cancelled or different attempt.
func continue_encounter(token: int) -> void:
    if not _session_active or not awaiting_continue or token != coordinator.session_id or not _accepted_result:
        return
    var result := _accepted_result
    _accepted_result = null
    awaiting_continue = false
    _session_active = false
    result_summary.hide()
    if is_instance_valid(_party):
        _party.release_encounter(self)
    encounter_completed.emit(result)


## Confirms collection after explicit inventory decisions. A failed validation
## reopens the panel without awarding any XP/items or releasing opponents.
func collect_rewards(token: int) -> void:
    if _reward_choice_is_current(token):
        _finish_attempt(token, coordinator.current_result)


## Checks that the reward panel still belongs to this session and finished attempt before accepting
## a choice.
func _reward_choice_is_current(token: int) -> bool:
    return (
        _session_active
        and awaiting_reward_choices
        and token == coordinator.session_id
        and coordinator.state == BattleCoordinator.STATE.FINISHED
    )


## Locate the original stack reference, not a stale numeric slot after compaction.
func _discard_stored_reward_item(token: int, item: ItemBase, amount: int) -> void:
    if not _reward_choice_is_current(token) or amount < 1:
        return
    for slot in range(1, _party.stash.size + 1):
        if _party.stash.slots[slot] == item and _party.stash.use_item(slot, amount):
            reward_inventory.present(_party.stash, coordinator.current_result, token)
            return


## Keep original foe loot history intact; only the player's retained offer changes.
func _decline_reward_item(token: int, index: int, amount: int) -> void:
    if not _reward_choice_is_current(token) or amount < 1:
        return
    var result := coordinator.current_result
    if index < 0 or index >= result.reward_offer.size():
        return
    var discarded: int = result.discarded_rewards.get(index, 0)
    if discarded + amount > result.reward_offer[index].count:
        return
    result.discarded_rewards[index] = discarded + amount
    reward_inventory.present(_party.stash, result, token)


## Restores the party's pre-battle state and starts another attempt, only if the supplied attempt
## number matches the pending retry.
func retry_encounter(token: int) -> bool:
    if not _session_active or not awaiting_retry or token != coordinator.session_id:
        return false
    awaiting_retry = false
    coordinator.cleanup(token)
    if not _checkpoint.restore():
        _fail_session("Retry failed: a permanent party unit is no longer available.")
        return false
    attempts += 1
    if not begin_encounter(_party, _foes, _encounter_id, _seed, _context, _rewards):
        _fail_session(last_error)
        return false
    return true


## Ends the session with an ERROR result and displays the failure message.
func _fail_session(message: String) -> void:
    _session_active = false
    last_error = message
    var result := BattleResult.new()
    result.encounter_id = _encounter_id
    result.battle_seed = _seed
    result.return_context = _context.duplicate(true)
    result.finalize(BattleResult.OUTCOME.ERROR, [], [], message)
    $Interface/ActionMenu.show_error(message)
    encounter_completed.emit(result)


## Stops turns and retries and cleans up the battle, without announcing a completed result.
func cancel_session() -> void:
    _session_active = false
    awaiting_retry = false
    awaiting_reward_choices = false
    awaiting_continue = false
    _accepted_result = null
    if is_instance_valid(reward_inventory):
        reward_inventory.hide()
    if is_instance_valid(result_summary):
        result_summary.hide()
    if is_instance_valid(_party):
        _party.release_encounter(self)
    flow.stop()
    coordinator.cleanup(coordinator.session_id)
    if not last_error.is_empty():
        $Interface/ActionMenu.show_error(last_error)


## Blocks saving throughout active play and retry prompts, otherwise deferring to the coordinator.
func get_save_block_reason() -> String:
    return (
        "Saving is unavailable during battle, retries or result confirmation."
        if _session_active
        else coordinator.get_save_block_reason()
    )


## Coordinator teardown handles combat-owned nodes; release a summary-only lease
## here too when a non-story caller frees this scene without explicit cancellation.
func _exit_tree() -> void:
    if is_instance_valid(_party):
        _party.release_encounter(self)


## Starts one battle attempt, sets up its displays and begins taking turns. Cleans up if display or
## turn setup fails.
func begin_encounter(
    party: BattlePartyManager,
    foes: Array[BattleUnitTemplate],
    encounter_id: StringName,
    battle_seed: int = 0,
    return_context: Dictionary = {},
    rewards: Dictionary = {},
) -> bool:
    if not coordinator.begin_encounter(party, foes, encounter_id, battle_seed, return_context, rewards):
        last_error = coordinator.last_error
        return false
    if not stage.bind_encounter(coordinator):
        last_error = stage.last_error
        coordinator.cleanup(coordinator.session_id)
        return false
    flow.flee_allowed = not _require_victory
    if not flow.start(coordinator, stage):
        last_error = "Production turn flow could not start."
        coordinator.cleanup(coordinator.session_id)
        return false
    last_error = ""
    return true
