extends Node2D

## Minimal playable view: builds a match, ticks the sim at a fixed rate, and
## draws everything with plain shapes. A Camera2D follows the player's hero and
## shows only part of the map. Pure render + input — all logic lives in sim/.

const LaneBotScript := preload("res://ai/lane_bot.gd")

const PX_PER_UNIT := 32.0        # world units -> pixels
const MAP_SPAN := 40.0           # map is 0..40 in both axes
const CAM_ZOOM := 1.6            # >1 zooms in (shows less of the map)
const CAM_MARGIN := 3.0          # world units of slack past the map edge

const COL_BLUE := Color(0.35, 0.55, 1.0)
const COL_RED := Color(1.0, 0.45, 0.4)
const COL_BG := Color(0.1, 0.11, 0.13)
const COL_LANE := Color(1, 1, 1, 0.12)

var world: World
var player_ctrl: PlayerController
var player_hero: Hero
var _camera: Camera2D

var _clock_label: Label      # match time, top-centre
var _status_label: Label     # player respawn, below the clock
var _avatars: Control        # top row of hero portraits (no names)

var _acc: float = 0.0

func _ready() -> void:
	world = MatchBuilder.build(LaneBotScript)
	# Hand the blue mid hero to the player instead of a bot.
	player_hero = _find_hero(Unit.Team.BLUE, Lane.Which.MID)
	player_ctrl = PlayerController.new()
	world.controllers[player_hero] = player_ctrl
	_setup_background()
	_setup_camera()
	_setup_hud()

func _setup_background() -> void:
	# Full-map dark backdrop drawn behind the camera's view.
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.position = Vector2(-CAM_MARGIN, -CAM_MARGIN) * PX_PER_UNIT
	bg.size = Vector2.ONE * (MAP_SPAN + 2 * CAM_MARGIN) * PX_PER_UNIT
	bg.z_index = -10
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

func _setup_camera() -> void:
	_camera = Camera2D.new()
	_camera.zoom = Vector2(CAM_ZOOM, CAM_ZOOM)
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 6.0
	# No limits: camera can look past the map edge (proper bounds come later).
	_camera.position = _w2s(player_hero.pos)
	add_child(_camera)
	_camera.make_current()

## Screen-fixed overlay (a CanvasLayer ignores the camera). Minimal on purpose —
## just the match clock and a line for the next creep wave / player respawn.
func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_clock_label = Label.new()
	_clock_label.add_theme_font_size_override("font_size", 34)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_label.anchor_left = 0.0
	_clock_label.anchor_right = 1.0
	_clock_label.offset_top = 16.0
	_clock_label.offset_bottom = 60.0
	_clock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_clock_label)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.anchor_left = 0.0
	_status_label.anchor_right = 1.0
	_status_label.offset_top = 58.0
	_status_label.offset_bottom = 90.0
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_status_label)

	# Top row of hero avatars (blue on the left, red on the right), drawn by hand.
	_avatars = Control.new()
	_avatars.anchor_right = 1.0
	_avatars.offset_bottom = 60.0
	_avatars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avatars.draw.connect(_draw_avatars)
	layer.add_child(_avatars)

func _update_hud() -> void:
	_clock_label.text = _fmt_time(world.time)
	if player_hero.respawning():
		_status_label.text = "Респавн %d" % ceili(player_hero.respawn_remaining())
	else:
		_status_label.text = ""
	if _avatars != null:
		_avatars.queue_redraw()

## Portrait row: each hero as a coloured disc, blue team packed from the left and
## red team from the right. No names. Dead/respawning heroes are dimmed; the
## player's own portrait gets a yellow ring. A thin hp bar sits under each.
## NOTE: the Control.draw signal passes no argument, so this takes none and draws
## straight onto _avatars.
func _draw_avatars() -> void:
	var r := 16.0
	var gap := 42.0
	var y := 24.0
	var width: float = _avatars.size.x
	var blue: Array[Hero] = []
	var red: Array[Hero] = []
	for h in world.heroes:
		(blue if h.team == Unit.Team.BLUE else red).append(h)
	for i in blue.size():
		_draw_avatar(blue[i], Vector2(16.0 + r + i * gap, y), r)
	for i in red.size():
		_draw_avatar(red[i], Vector2(width - 16.0 - r - i * gap, y), r)

func _draw_avatar(h: Hero, c: Vector2, r: float) -> void:
	var down := h.respawning() or not h.is_alive()
	var col := _team_col(h.team)
	if down:
		col = Color(col, 0.35)
	_avatars.draw_circle(c, r, col)
	# hp bar under the portrait
	var frac: float = clampf(h.hp / h.max_hp, 0.0, 1.0)
	var w := r * 2.0
	var tl := c + Vector2(-r, r + 3.0)
	_avatars.draw_rect(Rect2(tl, Vector2(w, 3.0)), Color(0, 0, 0, 0.6))
	_avatars.draw_rect(Rect2(tl, Vector2(w * frac, 3.0)), Color(0.4, 0.9, 0.4))

func _fmt_time(t: float) -> String:
	var total := int(t)
	return "%d:%02d" % [total / 60, total % 60]

func _process(delta: float) -> void:
	# Advance the sim in fixed steps, catching up but never spiralling.
	_acc += delta
	var steps := 0
	while _acc >= World.TICK_DT and steps < 5:
		world.tick()
		_acc -= World.TICK_DT
		steps += 1
	if _camera != null:
		_camera.position = _w2s(player_hero.pos)
	_update_hud()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	var screen_pos
	if event is InputEventScreenTouch and event.pressed:
		screen_pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		screen_pos = event.position
	else:
		return
	var wp: Vector2 = _screen_to_world(screen_pos)
	var target: Unit = _enemy_near(wp, 2.5)
	if target != null:
		player_ctrl.order_attack(target)
	else:
		player_ctrl.order_move(wp)

func _draw() -> void:
	# lanes as faint lines
	for lane in world.lanes:
		for i in range(lane.path.size() - 1):
			draw_line(_w2s(lane.path[i]), _w2s(lane.path[i + 1]), COL_LANE, 2.0 * PX_PER_UNIT)

	# towers (squares), nexus (big ring), minions (dots), heroes (circles)
	for t in world.towers:
		_draw_square(t, 9.0)
	for c in world.cores:
		_draw_core(c)
	for m in world.minions:
		var mp: Vector2 = _w2s(m.pos)
		draw_circle(mp, 4.0, _team_col(m.team))
		_draw_hp_bar(mp, 7.0, m.hp / m.max_hp, 12.0, 2.0)
	for h in world.heroes:
		_draw_hero(h)

	if world.winner != -1:
		var who := "BLUE" if world.winner == Unit.Team.BLUE else "RED"
		_draw_center_text("%s WINS" % who)

func _draw_hero(h: Hero) -> void:
	var p: Vector2 = _w2s(h.pos)
	if h.respawning():
		draw_circle(p, 10.0, Color(0.5, 0.5, 0.5, 0.4))
		var secs := ceili(h.respawn_remaining())
		var font := ThemeDB.fallback_font
		draw_string(font, p + Vector2(-5, -14), str(secs),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.9, 0.9))
		return
	draw_circle(p, 10.0, _team_col(h.team))
	_draw_hp_bar(p, 16.0, h.hp / h.max_hp)

func _draw_square(u: Unit, half: float) -> void:
	var p: Vector2 = _w2s(u.pos)
	# ring = shooting range, shown only while the tower is actually firing
	if _is_firing(u):
		draw_arc(p, u.attack_range * PX_PER_UNIT, 0, TAU, 48, Color(_team_col(u.team), 0.25), 1.5)
	draw_rect(Rect2(p - Vector2(half, half), Vector2(half, half) * 2.0), _team_col(u.team))
	_draw_hp_bar(p, half + 5.0, u.hp / u.max_hp)

func _is_firing(u: Unit) -> bool:
	return u.attack_target != null and u.attack_target.is_alive()

func _draw_core(c: BaseCore) -> void:
	var p: Vector2 = _w2s(c.pos)
	# ring = the nexus' defence range, shown only while it is actually firing
	if _is_firing(c):
		draw_arc(p, c.attack_range * PX_PER_UNIT, 0, TAU, 48, Color(_team_col(c.team), 0.25), 1.5)
	# small green disc right on the corner = the fountain heal spot
	draw_circle(p, World.BASE_HEAL_RADIUS * PX_PER_UNIT, Color(0.4, 0.9, 0.4, 0.2))
	draw_arc(p, 20.0, 0, TAU, 32, _team_col(c.team), 4.0)
	_draw_hp_bar(p, 26.0, c.hp / c.max_hp)

func _draw_hp_bar(center: Vector2, y_off: float, frac: float, w: float = 28.0, h: float = 3.0) -> void:
	frac = clampf(frac, 0.0, 1.0)
	var top_left := center + Vector2(-w / 2.0, -y_off - h - 1.0)
	draw_rect(Rect2(top_left, Vector2(w, h)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(top_left, Vector2(w * frac, h)), Color(0.4, 0.9, 0.4))

func _draw_center_text(text: String) -> void:
	var font := ThemeDB.fallback_font
	var anchor: Vector2 = _camera.get_screen_center_position() if _camera != null else Vector2.ZERO
	draw_string(font, anchor - Vector2(110, 0), text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 40, Color.WHITE)

# --- helpers ---

func _team_col(team: int) -> Color:
	return COL_BLUE if team == Unit.Team.BLUE else COL_RED

func _find_hero(team: int, which: int) -> Hero:
	for h in world.heroes:
		var ctrl = world.controllers.get(h)
		if h.team == team and ctrl != null and ctrl.lane != null and ctrl.lane.which == which:
			return h
	return world.heroes[0]

func _enemy_near(wp: Vector2, radius: float) -> Unit:
	var best: Unit = null
	var best_d: float = radius
	for u in world.enemies_of(player_hero):
		var d: float = wp.distance_to(u.pos)
		if d <= best_d:
			best_d = d
			best = u
	return best

func _w2s(p: Vector2) -> Vector2:
	return p * PX_PER_UNIT

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var xf := get_viewport().get_canvas_transform()
	var world_px: Vector2 = xf.affine_inverse() * screen_pos
	return world_px / PX_PER_UNIT
