extends SceneTree

func _init() -> void:
	var world := GameWorld.new()
	world.start_new_game(2026)
	for i: int in range(24):
		var active: Dictionary = world.task_queue.get_active_task()
		if active.is_empty():
			world.enqueue_task("task_reproduce_paper_0")
			active = world.task_queue.get_active_task()
		world.simulate_weeks(1)
		print(
			"w=",
			world.week,
			" active=",
			str(active.get("task_id", "")),
			"/",
			int(active.get("weeks_left", 0)),
			" cum=",
			world.cum_income,
			" money=",
			world.get_money(),
			" q=",
			world.task_queue.get_queue().size()
		)
	quit()
