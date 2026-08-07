extends Control

@onready var body: RichTextLabel = $Margin/Scroll/VBox/Body


func _ready() -> void:
	$Margin/Scroll/VBox/BtnContinue.pressed.connect(_on_continue)
	_fill()


func _fill() -> void:
	var roundup: Array = GameState.last_matchday_roundup
	if roundup.is_empty():
		body.text = "Sin resultados de jornada disponibles."
		return
	## Tu liga primero, luego la otra.
	var ordered: Array = roundup.duplicate()
	var player_league := GameState.player_league()
	if player_league:
		ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var a_mine: bool = str(a.get("league_id", "")) == player_league.id
			var b_mine: bool = str(b.get("league_id", "")) == player_league.id
			if a_mine == b_mine:
				return int(a.get("tier", 99)) < int(b.get("tier", 99))
			return a_mine
		)
	var text := "[b]Resultados y estadísticas de la jornada[/b]\n"
	text += "Tu liga aparece primero; debajo, la otra división.\n"
	for block in ordered:
		text += "\n--------------------------------\n"
		text += _format_league_block(block)
	body.text = text


func _format_league_block(block: Dictionary) -> String:
	var mine := ""
	var player_league := GameState.player_league()
	if player_league and str(block.get("league_id", "")) == player_league.id:
		mine = "  ★ TU LIGA"
	var text := "[b]%s%s[/b]\nTemporada %d · Jornada %d/%d\n\n" % [
		str(block.get("league_name", "")), mine,
		int(block.get("year", 0)),
		int(block.get("matchday", 0)),
		int(block.get("total_matchdays", 0)),
	]
	text += "[b]Resultados[/b]\n"
	var results: Array = block.get("results", [])
	if results.is_empty():
		text += "  (Sin partidos jugados)\n"
	for r in results:
		var mark := " ★" if r.get("is_player", false) else ""
		text += "\n[b]%s %d - %d %s%s[/b]\n" % [
			r.get("home_name", "?"), int(r.get("home_goals", 0)),
			int(r.get("away_goals", 0)), r.get("away_name", "?"), mark
		]
		text += "  Local: %s\n" % _format_scorers(r.get("home_scorers", []))
		text += "  Visita: %s\n" % _format_scorers(r.get("away_scorers", []))

	text += "\n[b]Clasificación[/b]\n"
	for row in block.get("table", []):
		var cname: String = str(row.get("name", ""))
		if row.get("is_player", false):
			cname = "★ " + cname
		text += "  %d. %s — %d pts  (PJ %d · G %d E %d P %d · GF %d GC %d DG %d)\n" % [
			int(row.get("pos", 0)), cname, int(row.get("points", 0)),
			int(row.get("played", 0)), int(row.get("won", 0)), int(row.get("drawn", 0)), int(row.get("lost", 0)),
			int(row.get("gf", 0)), int(row.get("ga", 0)), int(row.get("gd", 0)),
		]

	text += "\n[b]Goleadores (temp.)[/b]\n"
	var scorers: Array = block.get("top_scorers", [])
	if scorers.is_empty():
		text += "  Aún sin goles registrados.\n"
	else:
		var rank := 1
		for s in scorers:
			var sn: String = str(s.get("name", ""))
			if s.get("is_player_club", false):
				sn = "★ " + sn
			text += "  %d. %s (%s) — %d goles · %d asist.\n" % [
				rank, sn, s.get("club", "?"), int(s.get("goals", 0)), int(s.get("assists", 0))
			]
			rank += 1
	return text


func _format_scorers(scorers: Array) -> String:
	if scorers.is_empty():
		return "—"
	var parts: Array[String] = []
	for s in scorers:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var line: String = "%s %d'" % [str(s.get("name", "?")), int(s.get("minute", 0))]
		var assist: String = str(s.get("assist", ""))
		if assist != "":
			line += " (asist. %s)" % assist
		parts.append(line)
	return ", ".join(parts) if not parts.is_empty() else "—"


func _on_continue() -> void:
	get_tree().change_scene_to_file("res://scenes/office/matchday_news.tscn")
