extends Node
## Legacy debug-only adapter for queued headless encounters. Production story
## battles use BattleStorySession and BattleEncounterScene instead.
class_name BattleScene

## Maximum rounds before an unresolved encounter is finalized as a draw.
@export_range(1, 1000, 1, "or_greater")
var max_rounds: int = BattleHeadlessRunner.DEFAULT_MAX_ROUNDS
## Headless runner owned by this scene.
@onready var runner: BattleHeadlessRunner = $BattleHeadlessRunner

## One-shot guard that prevents the queued encounter from being deployed twice.
var started: bool


## SceneManager invokes this after loading and transition setup completes.
func start_scene() -> void:
    start_battle.call_deferred()


## Consumes the pending controller payload and returns its finalized result.
## Repeated calls return [code]null[/code] and do not start another battle.
func start_battle():
    if started:
        return null
    started = true
    BattleController.clear_presentation_adapter()
    var payload: Dictionary = BattleController.get_pending_battle_payload()
    var foe_templates: Array[BattleUnitTemplate] = []
    foe_templates.assign(payload.get("foes", []))
    if foe_templates.is_empty():
        BattleController.finish_battle(
            BattleResult.OUTCOME.ERROR,
            "Production battle scene received no queued foes."
        )
        return BattleController.last_battle_result
    var deployed: Dictionary = BattleController.init_battlefield_from_runtime_party(foe_templates)
    var allies: Array[BattleUnit] = []
    var foes: Array[BattleUnit] = []
    allies.assign(deployed.get("allies", []))
    foes.assign(deployed.get("foes", []))
    var session = BattleController.current_battle_result
    var result = await (
        runner
        . run_battle(
            allies,
            foes,
            session.encounter_id,
            session.battle_seed,
            session.return_context,
            max_rounds,
            session.rewards,
        )
    )
    BattleController.accept_battle_result(result)
    return result
