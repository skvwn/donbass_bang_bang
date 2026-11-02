extends SceneTree

## Headless smoke test for the sim. Run with:
##   godot --headless --script tests/headless_match.gd
## Builds a full 6-hero / 3-lane match, runs it, and checks the sim behaves.
## Exit code 0 = all checks passed, 1 = a check failed (good for CI).

const LaneBotScript := preload("res://ai/lane_bot.gd")

var _failures: int = 0

func _initialize() -> void:
	var w := MatchBuilder.build(LaneBotScript)

	_check("6 heroes built", w.heroes.size() == 6)
	_check("2 cores built", w.cores.size() == 2)
	_check("18 towers built", w.towers.size() == w.lanes.size() * 2 * 3)
	_check("no minions at start", w.minions.size() == 0)

	# Run up to the first wave (10s) plus a bit.
	_run_for(w, 11.0)
	_check("minions spawned after first wave",
		w.minions.size() == w.lanes.size() * 2 * World.MINIONS_PER_WAVE)
	_check("match not decided yet", w.winner == -1)

	# Everyone should be doing something: positions moved from spawn.
	var any_moved := false
	for h in w.heroes:
		if h.pos != MatchBuilder.BLUE_BASE and h.pos != MatchBuilder.RED_BASE:
			any_moved = true
	_check("at least one hero moved out of base", any_moved)

	# Force a win: delete RED's nexus and tick once.
	for c in w.cores:
		if c.team == Unit.Team.RED:
			c.take_damage(c.max_hp)
	w.tick()
	_check("BLUE wins when RED nexus falls", w.winner == Unit.Team.BLUE)

	w.teardown()

	print("")
	if _failures == 0:
		print("HEADLESS OK — all checks passed (sim time simulated: %.1fs)" % w.time)
		quit(0)
	else:
		print("HEADLESS FAIL — %d check(s) failed" % _failures)
		quit(1)

func _run_for(w: World, seconds: float) -> void:
	var ticks := int(seconds * World.TICK_HZ)
	for i in ticks:
		w.tick()

func _check(label: String, ok: bool) -> void:
	if ok:
		print("  ok  : ", label)
	else:
		print("  FAIL: ", label)
		_failures += 1
