## Checks a few surprising behaviors described in the script reference.
## These checks record current behavior, including known limitations; they are not
## recommendations for how the systems should behave after a future bug fix.
extends Node

## Printed only after every check has completed without an assertion failure.
const SUCCESS_MESSAGE := "DOCUMENTATION_BEHAVIOR_SMOKE_TEST: PASS"


## Runs isolated checks without loading or changing a player's saved game.
func _ready() -> void:
    _check_time_names()
    _check_queue_order()
    _check_audio_state()
    print(SUCCESS_MESSAGE) # lint:ignore debug-print -- Required test/CLI output.


## Confirms that all readable time names round-trip regardless of case.
func _check_time_names() -> void:
    for time_id in TimeAdministrator.TIMES.values():
        var label := TimeAdministrator.get_time_string(time_id)
        assert(label != "Invalid", "Every defined time must have a readable name.")
        assert(TimeAdministrator.time_string_to_id(label) == time_id)
        assert(TimeAdministrator.time_string_to_id(label.to_upper()) == time_id)
        assert(TimeAdministrator.time_string_to_id(label.to_lower()) == time_id)
    # Model an invalid external ID without a constant out-of-enum assignment.
    var invalid_time_id: int = TimeAdministrator.TIMES.values().min() - 1
    assert(TimeAdministrator.get_time_string(invalid_time_id as TimeAdministrator.TIMES) == "Invalid")
    assert(TimeAdministrator.time_string_to_id("unknown") == TimeAdministrator.TIMES.Dawn)


## Confirms insertion order using tasks that never run. Inserting before the
## third task currently puts the new task before the second task instead.
func _check_queue_order() -> void:
    var queue := TaskQueue.new(get_tree())
    queue.require_manual_flushing = true
    var first := Task.new(&"first")
    var second := Task.new(&"second")
    var third := Task.new(&"third")
    var inserted := Task.new(&"inserted")
    queue.put_last(first)
    queue.put_last(second)
    queue.put_last(third)
    queue.put_task_before(inserted, third)
    assert(
        queue._tasks == [first, inserted, second, third],
        "Update the documented insertion limitation if the index calculation changes."
    )
    var after := Task.new(&"after")
    queue.put_task_after(after, second)
    assert(queue._tasks == [first, inserted, second, after, third])
    var missing := Task.new(&"missing")
    var front := Task.new(&"front")
    var back := Task.new(&"back")
    queue.put_task_before(front, missing)
    queue.put_task_after(back, missing)
    assert(queue._tasks.front() == front and queue._tasks.back() == back)
    assert(queue.busy and first.state == Task.STATE.NONE)


## Saves settings on temporary 2D and 3D audio players, then restores them.
## Volume and pitch return to their saved values; position currently does not.
func _check_audio_state() -> void:
    var player_2d := LoadableAudioPlayer2D.new()
    add_child(player_2d)
    player_2d.global_position = Vector2(12, 34)
    player_2d.volume_db = -12.0
    player_2d.pitch_scale = 1.25
    var state_2d := player_2d.get_state()
    assert(state_2d.global_position == Vector2(12, 34))
    player_2d.global_position = Vector2(56, 78)
    player_2d.volume_db = -3.0
    player_2d.pitch_scale = 0.75
    player_2d.restore_state(state_2d)
    assert(is_equal_approx(player_2d.volume_db, -12.0))
    assert(is_equal_approx(player_2d.pitch_scale, 1.25))
    assert(
        player_2d.global_position == Vector2(56, 78),
        "Update the documentation if 2D audio position restoration has been fixed."
    )
    player_2d.free()
    var holder := Node3D.new()
    var player_3d := LoadableAudioPlayer3D.new()
    # Assign the owner before entering the tree: _ready connects to its exit signal.
    holder.add_child(player_3d)
    player_3d.owner = holder
    add_child(holder)
    player_3d.global_position = Vector3(1, 2, 3)
    player_3d.volume_db = -9.0
    player_3d.pitch_scale = 1.5
    var state_3d := player_3d.get_state()
    assert(state_3d.global_position == Vector3(1, 2, 3))
    player_3d.global_position = Vector3(4, 5, 6)
    player_3d.volume_db = -2.0
    player_3d.pitch_scale = 0.5
    player_3d.restore_state(state_3d)
    assert(is_equal_approx(player_3d.volume_db, -9.0))
    assert(is_equal_approx(player_3d.pitch_scale, 1.5))
    assert(
        player_3d.global_position == Vector3(4, 5, 6),
        "Update the documentation if 3D audio position restoration has been fixed."
    )
    player_3d.free()
    holder.free()
