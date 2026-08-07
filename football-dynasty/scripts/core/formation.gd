class_name Formation
extends RefCounted

## id -> { label, slots } — slots usan ints 0=POR 1=DEF 2=MED 3=DEL
const DEFAULT_ID := "442"

const CATALOG := {
	"442": {"label": "4-4-2", "slots": [0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3]},
	"433": {"label": "4-3-3", "slots": [0, 1, 1, 1, 1, 2, 2, 2, 3, 3, 3]},
	"352": {"label": "3-5-2", "slots": [0, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3]},
	"451": {"label": "4-5-1", "slots": [0, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3]},
	"532": {"label": "5-3-2", "slots": [0, 1, 1, 1, 1, 1, 2, 2, 2, 3, 3]},
	"343": {"label": "3-4-3", "slots": [0, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3]},
	"4231": {"label": "4-2-3-1", "slots": [0, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3]},
	"4141": {"label": "4-1-4-1", "slots": [0, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3]},
	"541": {"label": "5-4-1", "slots": [0, 1, 1, 1, 1, 1, 2, 2, 2, 2, 3]},
	"4321": {"label": "4-3-2-1", "slots": [0, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3]},
}

const COLOR_GK := Color(0.96, 0.93, 0.72, 1)
const COLOR_DEF := Color(0.78, 0.92, 0.80, 1)
const COLOR_MID := Color(0.78, 0.86, 0.96, 1)
const COLOR_ATT := Color(0.95, 0.82, 0.82, 1)


static func ids() -> Array:
	return ["442", "433", "352", "451", "532", "343", "4231", "4141", "541", "4321"]


static func label(formation_id: String) -> String:
	if CATALOG.has(formation_id):
		return str(CATALOG[formation_id]["label"])
	return str(CATALOG[DEFAULT_ID]["label"])


static func slots(formation_id: String) -> Array:
	var id := formation_id if CATALOG.has(formation_id) else DEFAULT_ID
	return (CATALOG[id]["slots"] as Array).duplicate()


static func counts(formation_id: String) -> Dictionary:
	var need := {0: 0, 1: 0, 2: 0, 3: 0}
	for s in slots(formation_id):
		var pos: int = int(s)
		need[pos] = int(need[pos]) + 1
	return need


static func color_for_position(pos: int) -> Color:
	match pos:
		0:
			return COLOR_GK
		1:
			return COLOR_DEF
		2:
			return COLOR_MID
		3:
			return COLOR_ATT
	return Color(0.9, 0.9, 0.9, 1)


static func slot_label(pos: int) -> String:
	match pos:
		0: return "POR"
		1: return "DEF"
		2: return "MED"
		3: return "DEL"
	return "?"
