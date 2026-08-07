class_name Season
extends RefCounted

var year: int = 2026
var current_matchday: int = 0
var total_matchdays: int = 0
## Array of matchdays; each matchday is Array of {home_id, away_id, played, home_goals, away_goals}
var fixtures: Array = []
var finished: bool = false


func generate_round_robin(club_ids: Array[String]) -> void:
	fixtures.clear()
	var teams: Array = club_ids.duplicate()
	if teams.size() % 2 == 1:
		teams.append("BYE")
	var n: int = teams.size()
	var rounds: int = n - 1
	var half: int = n / 2
	# Circle method
	var arr: Array = teams.duplicate()
	for round_i in rounds:
		var matchday: Array = []
		for i in half:
			var home: String = str(arr[i])
			var away: String = str(arr[n - 1 - i])
			if home != "BYE" and away != "BYE":
				if round_i % 2 == 0:
					matchday.append(_make_fixture(home, away))
				else:
					matchday.append(_make_fixture(away, home))
		fixtures.append(matchday)
		# Rotate
		var last = arr.pop_back()
		arr.insert(1, last)
	# Second half (return fixtures)
	var first_half: Array = fixtures.duplicate(true)
	for md in first_half:
		var return_md: Array = []
		for fx in md:
			return_md.append(_make_fixture(fx["away_id"], fx["home_id"]))
		fixtures.append(return_md)
	total_matchdays = fixtures.size()
	current_matchday = 0
	finished = false


func _make_fixture(home_id: String, away_id: String) -> Dictionary:
	return {
		"home_id": home_id,
		"away_id": away_id,
		"played": false,
		"home_goals": 0,
		"away_goals": 0,
		"home_scorers": [],
		"away_scorers": [],
	}


func get_current_fixtures() -> Array:
	if current_matchday < 0 or current_matchday >= fixtures.size():
		return []
	return fixtures[current_matchday]


func get_club_fixture(club_id: String) -> Dictionary:
	for fx in get_current_fixtures():
		if fx["home_id"] == club_id or fx["away_id"] == club_id:
			return fx
	return {}


func mark_fixture_played(
	home_id: String,
	away_id: String,
	home_goals: int,
	away_goals: int,
	home_scorers: Array = [],
	away_scorers: Array = []
) -> void:
	for fx in get_current_fixtures():
		if fx["home_id"] == home_id and fx["away_id"] == away_id:
			fx["played"] = true
			fx["home_goals"] = home_goals
			fx["away_goals"] = away_goals
			fx["home_scorers"] = home_scorers.duplicate(true)
			fx["away_scorers"] = away_scorers.duplicate(true)
			return


func all_current_played() -> bool:
	for fx in get_current_fixtures():
		if not fx["played"]:
			return false
	return true


func advance_matchday() -> bool:
	if not all_current_played():
		return false
	current_matchday += 1
	if current_matchday >= total_matchdays:
		finished = true
		current_matchday = total_matchdays - 1
		return false
	return true


func to_dict() -> Dictionary:
	return {
		"year": year,
		"current_matchday": current_matchday,
		"total_matchdays": total_matchdays,
		"fixtures": fixtures.duplicate(true),
		"finished": finished,
	}


static func from_dict(d: Dictionary) -> Season:
	var s := Season.new()
	s.year = int(d.get("year", 2026))
	s.current_matchday = int(d.get("current_matchday", 0))
	s.total_matchdays = int(d.get("total_matchdays", 0))
	s.fixtures = d.get("fixtures", []).duplicate(true)
	s.finished = bool(d.get("finished", false))
	return s
