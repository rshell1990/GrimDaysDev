extends Node
## Tracks runtime quests and their steps, and rebuilds them from saved data.
class_name QuestDirector

## Notification for restored.
signal restored
## Notification for quest added. Supplies [code]quest[/code] to connected functions.
signal quest_added(quest)
## Notification for quest failed. Supplies [code]quest[/code] to connected functions.
signal quest_failed(quest)
## Notification for quest completed. Supplies [code]quest[/code] to connected functions.
signal quest_completed(quest)

## Scene object used for active quest holder.
@export var active_quest_holder: Node
## Scene object used for completed quest holder.
@export var completed_quest_holder: Node
## Scene object used for failed quest holder.
@export var failed_quest_holder: Node
## Key used to identify this script’s data in saved state.
var save_name: String = "quests"

## Lookup table for active quests; keys select the corresponding stored values.
var active_quests: Dictionary
## Lookup table for completed quests; keys select the corresponding stored values.
var completed_quests: Dictionary
## Lookup table for failed quests; keys select the corresponding stored values.
var failed_quests: Dictionary


## When the node enters the scene, this function registers [code]self[/code] with
## [code]SaveAndLoadSystemManager[/code].
func _enter_tree() -> void:
    SaveAndLoadSystemManager.add_node(self)


## Passes the quest definition to the quest system to create an active quest.
func add_quest(quest: GameQuest) -> void:
    var quest_operator = init_quest(quest)
    active_quests[quest.id] = quest_operator
    active_quest_holder.add_child(quest_operator)


## Creates a QuestOperator, initializes it from the supplied quest definition, and returns it.
func init_quest(quest: GameQuest) -> QuestOperator:
    var new_quest: QuestOperator = QuestOperator.new()
    new_quest.init(quest)
    return new_quest


## Returns [code]active_quests.has(quest)[/code].
func has_quest(quest: StringName) -> bool:
    return active_quests.has(quest)


## Returns the requested quest's current step through the quest administrator.
func get_quest_step(quest: StringName) -> int:
    return active_quests[quest].step


## Searches active, completed and failed quest-holder nodes for the ID; returns null when none
## matches.
func get_quest(quest: StringName) -> QuestOperator:
    for quest_node in active_quest_holder.get_children():
        if quest_node.id == quest:
            return quest_node

    for quest_node in completed_quest_holder.get_children():
        if quest_node.id == quest:
            return quest_node

    for quest_node in failed_quest_holder.get_children():
        if quest_node.id == quest:
            return quest_node

    return null


## Removes the quest from the active lookup, moves its node to the failed holder, disables its
## processing and announces failure.
func fail_quest(quest: StringName) -> void:
    active_quests.erase(quest)
    for quest_node in active_quest_holder.get_children():
        if quest_node.id == quest:
            failed_quests[quest] = quest_node
            quest_node.reparent(failed_quest_holder)
            quest_node.process_mode = Node.PROCESS_MODE_DISABLED
            quest_failed.emit(quest_node)


## Removes the quest from the active lookup and disables its node. Currently moves it to the failed
## holder and does not record or announce completion.
func complete_quest(quest: StringName) -> void:
    active_quests.erase(quest)
    for quest_node in active_quest_holder.get_children():
        if quest_node.id == quest:
            quest_node.reparent(failed_quest_holder)
            quest_node.process_mode = Node.PROCESS_MODE_DISABLED


## Returns quest IDs and step numbers grouped under active, completed and failed keys.
func _get_state() -> Dictionary:
    var data: Dictionary = {}
    data.get_or_add("active", {})
    data.get_or_add("completed", {})
    data.get_or_add("failed", {})
    for active_id in active_quests.keys():
        data["active"][active_id] = active_quests[active_id].step
    for complete_id in completed_quests.keys():
        data["completed"][complete_id] = completed_quests[complete_id].step
    for failed_id in failed_quests.keys():
        data["failed"][failed_id] = failed_quests[failed_id].step

    return data


## Recreates saved quests and advances them to saved steps. The current implementation adds all
## three saved groups through the active-quest path.
func _on_load(data: Dictionary) -> void:
    if not data.info.has(save_name):
        return
    if not data.info.quests.has("active"):
        return
    var active: Dictionary = data.info.quests.active
    var completed: Dictionary = data.info.quests.completed
    var failed: Dictionary = data.info.quests.failed

    for active_id in active.keys():
        add_quest(Repositories.get_info(RepositoryTypes.QUESTS, active_id))
        var quest_node: QuestOperator = get_quest(active_id)
        quest_node.advance_to(active[active_id])

    for complete_id in completed.keys():
        add_quest(Repositories.get_info(RepositoryTypes.QUESTS, complete_id))
        var quest_node: QuestOperator = get_quest(complete_id)
        quest_node.advance_to(completed[complete_id])

    for failed_id in failed.keys():
        add_quest(Repositories.get_info(RepositoryTypes.QUESTS, failed_id))
        var quest_node: QuestOperator = get_quest(failed_id)
        quest_node.advance_to(failed[failed_id])


## Recreates quests at their saved steps and announces restoration after a brief wait. Completed and
## failed entries currently use the same active-quest creation path.
func restore(data: Dictionary) -> void:
    CustomLogger.hint(self, self.restore, "is restoring data.", CustomLogger.LEVEL.MILD)
    if not data.has("active"):
        CustomLogger.warn(
            self,
            self.restore,
            "[color=#5F0]" + name + " does not active quest data, and thus will abort...[/color]"
        )
        await SystemHelpers.start_timer(VNAnimationTimes.NEAR_INSTANT)
        restored.emit()
        return
    var active: Dictionary = data.active
    var completed: Dictionary = data.completed
    var failed: Dictionary = data.failed

    for active_id in active.keys():
        add_quest(Repositories.get_info(RepositoryTypes.QUESTS, active_id))
        var quest_node: QuestOperator = get_quest(active_id)
        quest_node.advance_to(active[active_id])

    for complete_id in completed.keys():
        add_quest(Repositories.get_info(RepositoryTypes.QUESTS, complete_id))
        var quest_node: QuestOperator = get_quest(complete_id)
        quest_node.advance_to(completed[complete_id])

    for failed_id in failed.keys():
        add_quest(Repositories.get_info(RepositoryTypes.QUESTS, failed_id))
        var quest_node: QuestOperator = get_quest(failed_id)
        quest_node.advance_to(failed[failed_id])

    await SystemHelpers.start_timer(VNAnimationTimes.NEAR_INSTANT)
    restored.emit()
