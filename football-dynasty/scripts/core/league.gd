class_name League
extends RefCounted

var id: String = ""
var name: String = ""
var tier: int = 1 ## 1 = top
var club_ids: Array[String] = []
## club_id -> standings dict
var standings: Dictionary = {}


func init_standings() -> void:
	standings.clear()
	for cid in club_ids:
		standings[cid] = {
			"played": 0,
			"won": 0,
			"drawn": 0,
			"lost": 0,
			"gf": 0,
			"ga": 0,
			"points": 0,
		}


func apply_result(home_id: String, away_id: String, home_goals: int, away_goals: int) -> void:
	if not standings.has(home_id) or not standings.has(away_id):
		return
	var h: Dictionary = standings[home_id]
	var a: Dictionary = standings[away_id]
	h["played"] += 1
	a["played"] += 1
	h["gf"] += home_goals
	h["ga"] += away_goals
	a["gf"] += away_goals
	a["ga"] += home_goals
	if home_goals > away_goals:
		h["won"] += 1
		h["points"] += 3
		a["lost"] += 1
	elif home_goals < away_goals:
		a["won"] += 1
		a["points"] += 3
		h["lost"] += 1
	else:
		h["drawn"] += 1
		a["drawn"] += 1
		h["points"] += 1
		a["points"] += 1


func sorted_table() -> Array:
	var rows: Array = []
	for cid in standings.keys():
		var s: Dictionary = standings[cid].duplicate()
		s["club_id"] = cid
		s["gd"] = int(s["gf"]) - int(s["ga"])
		rows.append(s)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["points"] != b["points"]:
			return a["points"] > b["points"]
		if a["gd"] != b["gd"]:
			return a["gd"] > b["gd"]
		return a["gf"] > b["gf"]
	)
	return rows


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"tier": tier,
		"club_ids": club_ids.duplicate(),
		"standings": standings.duplicate(true),
	}


static func from_dict(d: Dictionary) -> League:
	var l := League.new()
	l.id = d.get("id", "")
	l.name = d.get("name", "")
	l.tier = int(d.get("tier", 1))
	l.club_ids.clear()
	for cid in d.get("club_ids", []):
		l.club_ids.append(str(cid))
	l.standings = d.get("standings", {}).duplicate(true)
	if l.standings.is_empty():
		l.init_standings()
	return l
