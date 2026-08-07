extends Control

const FormationUtil = preload("res://scripts/core/formation.gd")
const StaffSvc = preload("res://scripts/core/staff_service.gd")

@onready var lineup_list: ItemList = $Margin/Scroll/VBox/HBox/LineupBox/LineupList
@onready var bench_list: ItemList = $Margin/Scroll/VBox/HBox/BenchBox/BenchList
@onready var mentality: OptionButton = $Margin/Scroll/VBox/MentalityRow/Mentality
@onready var formation: OptionButton = $Margin/Scroll/VBox/FormationRow/Formation
@onready var title: Label = $Margin/Scroll/VBox/Title
@onready var info: Label = $Margin/Scroll/VBox/Info
@onready var advice: Label = $Margin/Scroll/VBox/Advice

var _last_advice: Dictionary = {}


func _ready() -> void:
	_setup_formation_options()
	mentality.clear()
	mentality.add_item("Defensiva", 0)
	mentality.add_item("Normal", 1)
	mentality.add_item("Ofensiva", 2)
	var club := GameState.player_club
	if club:
		club.ensure_default_lineup()
		mentality.select(club.mentality)
		_select_formation(club.formation_id)
	mentality.item_selected.connect(_on_mentality)
	formation.item_selected.connect(_on_formation)
	$Margin/Scroll/VBox/BtnSwap.pressed.connect(_on_swap)
	$Margin/Scroll/VBox/BtnAuto.pressed.connect(_on_auto)
	$Margin/Scroll/VBox/BtnAdvice.pressed.connect(_on_advice)
	$Margin/Scroll/VBox/BtnApplyAdvice.pressed.connect(_on_apply_advice)
	_last_advice = {}
	_refresh()


func _setup_formation_options() -> void:
	formation.clear()
	var i := 0
	for fid in FormationUtil.ids():
		formation.add_item(FormationUtil.label(fid), i)
		formation.set_item_metadata(i, fid)
		i += 1


func _select_formation(formation_id: String) -> void:
	for i in formation.item_count:
		if str(formation.get_item_metadata(i)) == formation_id:
			formation.select(i)
			return
	formation.select(0)


func _refresh() -> void:
	var club := GameState.player_club
	lineup_list.clear()
	bench_list.clear()
	if club == null:
		return
	title.text = "Alineación y táctica (%s)" % FormationUtil.label(club.formation_id)
	var slots: Array = FormationUtil.slots(club.formation_id)
	for i in club.lineup_ids.size():
		var pid: String = club.lineup_ids[i]
		var p := club.get_player(pid)
		if p == null:
			continue
		var slot_pos: int = int(slots[i]) if i < slots.size() else int(p.position)
		var out_of_pos := ""
		if int(p.position) != slot_pos:
			out_of_pos = " →%s" % FormationUtil.slot_label(slot_pos)
		var idx := lineup_list.item_count
		lineup_list.add_item("%s %s (%d)%s" % [p.position_label(), p.display_name(), p.overall(), out_of_pos])
		lineup_list.set_item_metadata(idx, p.id)
		lineup_list.set_item_custom_bg_color(idx, FormationUtil.color_for_position(int(p.position)))
	for pid2 in club.bench_ids:
		var p2 := club.get_player(pid2)
		if p2 == null:
			continue
		var bidx := bench_list.item_count
		var injured_tag := " LES" if p2.injured else ""
		bench_list.add_item("%s %s (%d)%s" % [p2.position_label(), p2.display_name(), p2.overall(), injured_tag])
		bench_list.set_item_metadata(bidx, p2.id)
		bench_list.set_item_custom_bg_color(bidx, FormationUtil.color_for_position(int(p2.position)))
	var counts: Dictionary = FormationUtil.counts(club.formation_id)
	info.text = "Formación %s (POR %d · DEF %d · MED %d · DEL %d) · Titulares %d · Banquillo %d · Fuerza XI: %.0f\nColores: amarillo POR · verde DEF · azul MED · rojo DEL. Si un titular cubre otro rol, verás →ROL." % [
		FormationUtil.label(club.formation_id),
		counts[0], counts[1], counts[2], counts[3],
		club.lineup_ids.size(), club.bench_ids.size(), club.squad_strength()
	]


func _on_mentality(index: int) -> void:
	GameState.player_club.mentality = mentality.get_item_id(index)


func _on_formation(index: int) -> void:
	var club := GameState.player_club
	if club == null:
		return
	club.formation_id = str(formation.get_item_metadata(index))
	club.rebuild_lineup()
	_refresh()


func _on_swap() -> void:
	var club := GameState.player_club
	var li := lineup_list.get_selected_items()
	var bi := bench_list.get_selected_items()
	if li.is_empty() or bi.is_empty():
		info.text = "Selecciona un titular y un suplente para intercambiar."
		return
	var out_id: String = lineup_list.get_item_metadata(li[0])
	var in_id: String = bench_list.get_item_metadata(bi[0])
	var out_idx := club.lineup_ids.find(out_id)
	if out_idx < 0:
		return
	club.lineup_ids[out_idx] = in_id
	club.bench_ids.erase(in_id)
	club.bench_ids.append(out_id)
	_refresh()


func _on_auto() -> void:
	var club := GameState.player_club
	club.rebuild_lineup()
	_refresh()


func _on_advice() -> void:
	_last_advice = StaffSvc.assistant_advice(GameState.player_club)
	advice.text = str(_last_advice.get("text", ""))


func _on_apply_advice() -> void:
	if _last_advice.is_empty() or not bool(_last_advice.get("ok", false)):
		_on_advice()
	if not bool(_last_advice.get("ok", false)):
		return
	var club := GameState.player_club
	club.formation_id = str(_last_advice["formation_id"])
	club.mentality = int(_last_advice["mentality"])
	mentality.select(club.mentality)
	_select_formation(club.formation_id)
	club.rebuild_lineup()
	advice.text = str(_last_advice.get("text", "")) + "\nAplicado: formación y mentalidad actualizadas."
	_refresh()
