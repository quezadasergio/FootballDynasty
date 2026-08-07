extends Control

@onready var title: Label = $Margin/VBox/Title
@onready var subtitle: Label = $Margin/VBox/Subtitle
@onready var league_pick: OptionButton = $Margin/VBox/LeaguePick
@onready var standings: Tree = $Margin/VBox/Tabs/Clasificación/StandingsTree
@onready var scorers: Tree = $Margin/VBox/Tabs/Goleadores/ScorersTree
@onready var assists: Tree = $Margin/VBox/Tabs/Asistencias/AssistsTree
@onready var cards: Tree = $Margin/VBox/Tabs/Disciplina/CardsTree
@onready var results: RichTextLabel = $Margin/VBox/Tabs/Resultados/ResultsBody

var _league_ids: Array[String] = []


func _ready() -> void:
	_setup_standings_tree()
	_setup_player_tree(scorers, ["#", "Jugador", "Club", "Pos", "Goles", "PJ"])
	_setup_player_tree(assists, ["#", "Jugador", "Club", "Pos", "Asistencias", "PJ"])
	_setup_player_tree(cards, ["#", "Jugador", "Club", "Pos", "TA", "TR", "PJ"])
	_fill_league_pick()
	league_pick.item_selected.connect(func(_i): _refresh())
	_refresh()


func _fill_league_pick() -> void:
	league_pick.clear()
	_league_ids.clear()
	var ordered: Array = GameState.leagues.values()
	ordered.sort_custom(func(a: League, b: League) -> bool: return a.tier < b.tier)
	var select_idx := 0
	for i in ordered.size():
		var league: League = ordered[i]
		league_pick.add_item(league.name, i)
		_league_ids.append(league.id)
		if GameState.player_club and league.id == GameState.player_club.league_id:
			select_idx = i
	if _league_ids.size() > 0:
		league_pick.select(select_idx)


func _selected_league() -> League:
	if _league_ids.is_empty():
		return GameState.player_league()
	var idx: int = league_pick.selected
	if idx < 0 or idx >= _league_ids.size():
		idx = 0
	return GameState.leagues.get(_league_ids[idx])


func _setup_standings_tree() -> void:
	standings.columns = 10
	standings.set_column_titles_visible(true)
	var headers := ["#", "Club", "PJ", "G", "E", "P", "GF", "GC", "DG", "Pts"]
	var widths := [40, 220, 48, 40, 40, 40, 48, 48, 48, 52]
	for i in headers.size():
		standings.set_column_title(i, headers[i])
		standings.set_column_custom_minimum_width(i, widths[i])
		standings.set_column_expand(i, i == 1)
		standings.set_column_clip_content(i, true)


func _setup_player_tree(tree: Tree, headers: Array) -> void:
	tree.columns = headers.size()
	tree.set_column_titles_visible(true)
	var widths := [40, 200, 160, 48, 90, 48]
	if headers.size() == 7:
		widths = [40, 180, 140, 48, 48, 48, 48]
	for i in headers.size():
		tree.set_column_title(i, str(headers[i]))
		tree.set_column_custom_minimum_width(i, widths[i] if i < widths.size() else 60)
		tree.set_column_expand(i, i == 1 or i == 2)
		tree.set_column_clip_content(i, true)


func _refresh() -> void:
	var league := _selected_league()
	if league == null:
		title.text = "Estadísticas de liga"
		return
	title.text = league.name
	var season: Season = GameState.seasons.get(league.id)
	var md := (season.current_matchday + 1) if season else 0
	var total := season.total_matchdays if season else 0
	var yours := " · Tu liga" if (GameState.player_club and GameState.player_club.league_id == league.id) else " · Otra división"
	subtitle.text = "Temporada %d · Jornada %d/%d%s · Tu club marcado con ★" % [
		season.year if season else 0, md, total, yours
	]
	_fill_standings(league)
	_fill_player_rankings(league)
	_fill_results(league, season)


func _fill_standings(league: League) -> void:
	standings.clear()
	var root := standings.create_item()
	var rows: Array = league.sorted_table()
	var i := 1
	for row in rows:
		var club: Club = GameState.get_club(row["club_id"])
		var club_name: String = club.name if club else str(row["club_id"])
		var is_player: bool = row["club_id"] == GameState.player_club_id
		if is_player:
			club_name = "★ " + club_name
		var item := standings.create_item(root)
		item.set_text(0, str(i))
		item.set_text(1, club_name)
		item.set_text(2, str(row["played"]))
		item.set_text(3, str(row["won"]))
		item.set_text(4, str(row["drawn"]))
		item.set_text(5, str(row["lost"]))
		item.set_text(6, str(row["gf"]))
		item.set_text(7, str(row["ga"]))
		item.set_text(8, str(row["gd"]))
		item.set_text(9, str(row["points"]))
		for col in range(2, 10):
			item.set_text_alignment(col, HORIZONTAL_ALIGNMENT_CENTER)
		item.set_text_alignment(0, HORIZONTAL_ALIGNMENT_CENTER)
		if is_player:
			item.set_custom_bg_color(1, Color(0.2, 0.35, 0.25, 0.55))
		if league.tier > 1 and i <= 3:
			item.set_custom_color(0, Color(0.55, 0.9, 0.6))
		elif league.tier == 1 and i > rows.size() - 3:
			item.set_custom_color(0, Color(0.95, 0.55, 0.5))
		i += 1


func _fill_player_rankings(league: League) -> void:
	var entries: Array = _league_player_entries(league)
	_fill_stat_tree(scorers, entries, "goals", true)
	_fill_stat_tree(assists, entries, "assists", true)
	_fill_cards_tree(entries)


func _fill_results(league: League, season: Season) -> void:
	if results == null:
		return
	if season == null:
		results.text = "Sin temporada."
		return
	var text := ""
	var any := false
	for fx in season.get_current_fixtures():
		if not fx.get("played", false):
			continue
		if not any:
			text += "[b]Resultados jornada %d[/b]\n\n" % (season.current_matchday + 1)
		any = true
		var home: Club = GameState.get_club(fx["home_id"])
		var away: Club = GameState.get_club(fx["away_id"])
		var mark := ""
		if fx["home_id"] == GameState.player_club_id or fx["away_id"] == GameState.player_club_id:
			mark = " ★"
		text += "[b]%s %d-%d %s%s[/b]\n" % [
			home.name if home else "?", int(fx.get("home_goals", 0)),
			int(fx.get("away_goals", 0)), away.name if away else "?", mark
		]
		text += "  Local: %s\n  Visita: %s\n\n" % [
			_format_scorers(fx.get("home_scorers", [])),
			_format_scorers(fx.get("away_scorers", [])),
		]
	if any:
		results.text = text
		return
	for block in GameState.last_matchday_roundup:
		if str(block.get("league_id", "")) != league.id:
			continue
		text = "[b]Última jornada cerrada (%d)[/b]\n\n" % int(block.get("matchday", 0))
		for r in block.get("results", []):
			var mark2 := " ★" if r.get("is_player", false) else ""
			text += "[b]%s %d-%d %s%s[/b]\n" % [
				r.get("home_name", "?"), int(r.get("home_goals", 0)),
				int(r.get("away_goals", 0)), r.get("away_name", "?"), mark2
			]
			text += "  Local: %s\n  Visita: %s\n\n" % [
				_format_scorers(r.get("home_scorers", [])),
				_format_scorers(r.get("away_scorers", [])),
			]
		results.text = text if text != "" else "Sin resultados todavía."
		return
	results.text = "Aún no hay resultados. Juega o avanza una jornada."


func _format_scorers(scorers_arr: Array) -> String:
	if scorers_arr.is_empty():
		return "—"
	var parts: Array[String] = []
	for s in scorers_arr:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var line: String = "%s %d'" % [str(s.get("name", "?")), int(s.get("minute", 0))]
		var assist: String = str(s.get("assist", ""))
		if assist != "":
			line += " (asist. %s)" % assist
		parts.append(line)
	return ", ".join(parts) if not parts.is_empty() else "—"


func _league_player_entries(league: League) -> Array:
	var entries: Array = []
	for cid in league.club_ids:
		var club: Club = GameState.get_club(cid)
		if club == null:
			continue
		for p in club.players:
			entries.append({
				"player": p,
				"club_name": club.name,
				"club_id": club.id,
				"goals": p.goals,
				"assists": p.assists,
				"yellow": p.yellow_cards,
				"red": p.red_cards,
				"played": p.matches_played,
			})
	return entries


func _fill_stat_tree(tree: Tree, entries: Array, key: String, require_positive: bool) -> void:
	tree.clear()
	var root := tree.create_item()
	var sorted := entries.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a[key]) != int(b[key]):
			return int(a[key]) > int(b[key])
		return a["player"].overall() > b["player"].overall()
	)
	var rank := 1
	var shown := 0
	for e in sorted:
		if require_positive and int(e[key]) <= 0:
			continue
		var p: Player = e["player"]
		var item := tree.create_item(root)
		item.set_text(0, str(rank))
		item.set_text(1, p.display_name())
		var cname: String = str(e["club_name"])
		if e["club_id"] == GameState.player_club_id:
			cname = "★ " + cname
		item.set_text(2, cname)
		item.set_text(3, p.position_label())
		item.set_text(4, str(e[key]))
		item.set_text(5, str(e["played"]))
		item.set_text_alignment(0, HORIZONTAL_ALIGNMENT_CENTER)
		item.set_text_alignment(3, HORIZONTAL_ALIGNMENT_CENTER)
		item.set_text_alignment(4, HORIZONTAL_ALIGNMENT_CENTER)
		item.set_text_alignment(5, HORIZONTAL_ALIGNMENT_CENTER)
		if e["club_id"] == GameState.player_club_id:
			item.set_custom_bg_color(1, Color(0.2, 0.35, 0.25, 0.55))
		rank += 1
		shown += 1
		if shown >= 25:
			break
	if shown == 0:
		var empty := tree.create_item(root)
		empty.set_text(1, "Aún no hay datos esta temporada.")


func _fill_cards_tree(entries: Array) -> void:
	cards.clear()
	var root := cards.create_item()
	var sorted := entries.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa: int = int(a["red"]) * 3 + int(a["yellow"])
		var sb: int = int(b["red"]) * 3 + int(b["yellow"])
		if sa != sb:
			return sa > sb
		return int(a["red"]) > int(b["red"])
	)
	var rank := 1
	var shown := 0
	for e in sorted:
		if int(e["yellow"]) <= 0 and int(e["red"]) <= 0:
			continue
		var p: Player = e["player"]
		var item := cards.create_item(root)
		item.set_text(0, str(rank))
		item.set_text(1, p.display_name())
		var cname: String = str(e["club_name"])
		if e["club_id"] == GameState.player_club_id:
			cname = "★ " + cname
		item.set_text(2, cname)
		item.set_text(3, p.position_label())
		item.set_text(4, str(e["yellow"]))
		item.set_text(5, str(e["red"]))
		item.set_text(6, str(e["played"]))
		for col in [0, 3, 4, 5, 6]:
			item.set_text_alignment(col, HORIZONTAL_ALIGNMENT_CENTER)
		if e["club_id"] == GameState.player_club_id:
			item.set_custom_bg_color(1, Color(0.2, 0.35, 0.25, 0.55))
		rank += 1
		shown += 1
		if shown >= 25:
			break
	if shown == 0:
		var empty := cards.create_item(root)
		empty.set_text(1, "Sin tarjetas registradas todavía.")
