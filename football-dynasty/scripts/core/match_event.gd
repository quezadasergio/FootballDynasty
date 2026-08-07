class_name MatchEvent
extends RefCounted

enum Type { CHANCE, GOAL, CARD_YELLOW, CARD_RED, INJURY, HALFTIME, FULLTIME, COMMENTARY }

var type: Type = Type.COMMENTARY
var minute: int = 0
var team_id: String = ""
var player_id: String = ""
var assist_id: String = ""
var home_goals: int = 0
var away_goals: int = 0
var text: String = ""


func to_dict() -> Dictionary:
	return {
		"type": type,
		"minute": minute,
		"team_id": team_id,
		"player_id": player_id,
		"assist_id": assist_id,
		"home_goals": home_goals,
		"away_goals": away_goals,
		"text": text,
	}
