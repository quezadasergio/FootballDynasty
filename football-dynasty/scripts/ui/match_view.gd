extends Control

@onready var score: Label = $UI/Top/Score
@onready var feed: ItemList = $UI/Right/Feed
@onready var speed_label: Label = $UI/Top/SpeedLabel
@onready var pause_btn: Button = $UI/Bottom/Controls/PauseBtn
@onready var mentality: OptionButton = $UI/Bottom/Controls/Mentality
@onready var lineup_list: ItemList = $UI/Bottom/SubBox/LineupList
@onready var bench_list: ItemList = $UI/Bottom/SubBox/BenchList
@onready var presenter: Control = $HighlightPresenter
@onready var sub_msg: Label = $UI/Bottom/SubMsg

var engine: MatchEngine
var home: Club
var away: Club
var speed: float = 1.0
var _busy: bool = false
var _event_queue: Array[MatchEvent] = []
var _accum: float = 0.0
const BASE_TICK_INTERVAL := 0.12


func _ready() -> void:
	var season := GameState.player_season()
	var fx := season.get_club_fixture(GameState.player_club_id)
	home = GameState.get_club(fx["home_id"])
	away = GameState.get_club(fx["away_id"])
	home.ensure_default_lineup()
	away.ensure_default_lineup()

	engine = MatchEngine.new()
	engine.setup(home, away)
	engine.event_generated.connect(_on_event)
	engine.match_finished.connect(_on_finished)

	mentality.clear()
	mentality.add_item("Defensiva", 0)
	mentality.add_item("Normal", 1)
	mentality.add_item("Ofensiva", 2)
	mentality.select(GameState.player_club.mentality)
	mentality.item_selected.connect(_on_mentality)

	pause_btn.pressed.connect(_toggle_pause)
	$UI/Bottom/Controls/Speed1.pressed.connect(func(): _set_speed(1.0))
	$UI/Bottom/Controls/Speed2.pressed.connect(func(): _set_speed(2.5))
	$UI/Bottom/Controls/SpeedSkip.pressed.connect(func(): _set_speed(8.0))
	$UI/Bottom/SubBtn.pressed.connect(_on_sub)
	$UI/Bottom/BackDisabled.visible = false

	_refresh_subs()
	_update_score()
	feed.add_item("¡Comienza el partido!")


func _process(delta: float) -> void:
	if engine == null or engine.finished:
		return
	if engine.paused:
		return
	_accum += delta * speed
	while _accum >= BASE_TICK_INTERVAL and not engine.finished and not engine.paused:
		_accum -= BASE_TICK_INTERVAL
		engine.tick()
		_update_score()
	_drain_queue()


func _drain_queue() -> void:
	if _busy or _event_queue.is_empty():
		return
	var ev: MatchEvent = _event_queue.pop_front()
	_busy = true
	# Only animate notable events; commentary is quick
	var notable := ev.type in [
		MatchEvent.Type.GOAL, MatchEvent.Type.CHANCE, MatchEvent.Type.CARD_YELLOW,
		MatchEvent.Type.CARD_RED, MatchEvent.Type.INJURY, MatchEvent.Type.HALFTIME, MatchEvent.Type.FULLTIME
	]
	if notable and speed < 6.0:
		await presenter.play_event(ev, home.primary_color, away.primary_color)
	else:
		await get_tree().create_timer(0.05 / maxf(speed, 0.5)).timeout
	_busy = false


func _on_event(ev: MatchEvent) -> void:
	feed.add_item("%d' %s" % [ev.minute, ev.text])
	feed.select(feed.item_count - 1)
	feed.ensure_current_is_visible()
	if ev.type != MatchEvent.Type.COMMENTARY or ev.text.contains("entra por"):
		_event_queue.append(ev)
	_update_score()
	if ev.type == MatchEvent.Type.INJURY or ev.text.contains("entra por"):
		_refresh_subs()


func _on_finished(_hg: int, _ag: int) -> void:
	GameState.apply_player_match_result(
		home, away, engine.home_goals, engine.away_goals,
		engine.home_goal_scorers, engine.away_goal_scorers
	)
	GameState.simulate_cpu_fixtures_except_player()
	await get_tree().create_timer(0.8).timeout
	get_tree().change_scene_to_file("res://scenes/match/match_summary.tscn")


func _update_score() -> void:
	score.text = "%s  %d - %d  %s   (%d')" % [
		home.short_name, engine.home_goals, engine.away_goals, away.short_name, engine.minute
	]
	speed_label.text = "Vel: %.1fx%s" % [speed, "  PAUSA" if engine.paused else ""]


func _set_speed(v: float) -> void:
	speed = v
	_update_score()


func _toggle_pause() -> void:
	engine.paused = not engine.paused
	pause_btn.text = "Reanudar" if engine.paused else "Pausar"
	_update_score()
	_refresh_subs()


func _on_mentality(index: int) -> void:
	var m := mentality.get_item_id(index)
	GameState.player_club.mentality = m
	engine.set_mentality(GameState.player_club_id, m)


func _refresh_subs() -> void:
	lineup_list.clear()
	bench_list.clear()
	var club := GameState.player_club
	for pid in club.lineup_ids:
		var p := club.get_player(pid)
		if p:
			lineup_list.add_item("%s %s (%.0f)" % [p.position_label(), p.display_name(), p.stamina])
			lineup_list.set_item_metadata(lineup_list.item_count - 1, p.id)
	for pid in club.bench_ids:
		var p2 := club.get_player(pid)
		if p2 and not p2.injured:
			bench_list.add_item("%s %s" % [p2.position_label(), p2.display_name()])
			bench_list.set_item_metadata(bench_list.item_count - 1, p2.id)


func _on_sub() -> void:
	if not engine.paused:
		sub_msg.text = "Pausa el partido para hacer un cambio."
		return
	var li := lineup_list.get_selected_items()
	var bi := bench_list.get_selected_items()
	if li.is_empty() or bi.is_empty():
		sub_msg.text = "Elige titular y suplente."
		return
	var out_id: String = lineup_list.get_item_metadata(li[0])
	var in_id: String = bench_list.get_item_metadata(bi[0])
	var err := engine.make_substitution(GameState.player_club_id, out_id, in_id)
	sub_msg.text = err if err != "" else "Cambio realizado."
	_refresh_subs()
