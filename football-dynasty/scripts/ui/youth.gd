extends Control

const Youth = preload("res://scripts/core/youth_service.gd")
const StaffScript = preload("res://scripts/core/staff_member.gd")

@onready var info: Label = $Margin/Scroll/HBox/Left/Info
@onready var youth_list: ItemList = $Margin/Scroll/HBox/Left/YouthList
@onready var detail: RichTextLabel = $Margin/Scroll/HBox/Left/Detail
@onready var status: Label = $Margin/Scroll/HBox/Left/Status
@onready var coach_info: Label = $Margin/Scroll/HBox/Right/CoachInfo
@onready var plan_advice: RichTextLabel = $Margin/Scroll/HBox/Right/PlanAdvice
@onready var plan_pick: OptionButton = $Margin/Scroll/HBox/Right/PlanRow/PlanPick
@onready var progress: RichTextLabel = $Margin/Scroll/HBox/Right/Progress


func _ready() -> void:
	youth_list.item_selected.connect(_on_selected)
	$Margin/Scroll/HBox/Left/BtnPromote.pressed.connect(_on_promote)
	$Margin/Scroll/HBox/Right/BtnAskPlan.pressed.connect(_on_ask_plan)
	$Margin/Scroll/HBox/Right/PlanRow/BtnSetPlan.pressed.connect(_on_set_plan)
	plan_pick.clear()
	for p in Youth.PLANS:
		plan_pick.add_item(str(p["label"]))
		plan_pick.set_item_metadata(plan_pick.item_count - 1, str(p["id"]))
	_populate()


func _populate() -> void:
	var club := GameState.player_club
	if club == null:
		return
	var sorted := club.youth_players.duplicate()
	sorted.sort_custom(func(a: Player, b: Player) -> bool:
		if a.age != b.age:
			return a.age > b.age
		return a.overall() > b.overall()
	)
	youth_list.clear()
	for p in sorted:
		var ready_tag := " [LISTO]" if p.age >= Youth.PROMOTE_AGE else ""
		var inj := " LES%d" % p.injury_matchdays if p.injured else ""
		youth_list.add_item("%s %s · %d años · OVR%d%s%s" % [
			p.position_label(), p.display_name(), p.age, p.overall(), ready_tag, inj
		])
		youth_list.set_item_metadata(youth_list.item_count - 1, p.id)

	info.text = "Camada: %d chicos (mínimo %d, máximo %d) de 14 a 19 años.\nA partir de los %d pueden subir al primer equipo; mientras sean menores de %d pueden regresar.\nSueldos juveniles: %s/jornada · Academia: %s/jornada" % [
		club.youth_players.size(), Youth.MIN_SQUAD, Youth.MAX_SQUAD,
		Youth.PROMOTE_AGE, Youth.RETURN_AGE_LIMIT,
		_money(club.youth_wage_bill()), _money(club.academy_cost()),
	]

	var coach = club.get_staff(StaffScript.Role.YOUTH)
	if coach:
		coach_info.text = "%s (hab. %d) · %s/jornada\nPlan activo: %s" % [
			coach.staff_name, coach.skill, _money(coach.wage),
			Youth.plan_label(club.youth_plan) if club.youth_plan != "" else "ninguno",
		]
	else:
		coach_info.text = "Puesto vacante. Contrátalo en Plantilla → Cuerpo técnico para recibir un plan y acelerar el desarrollo."
	_select_plan(club.youth_plan)

	var improved: Array = GameState.last_matchday_youth
	if improved.is_empty():
		progress.text = "[b]Última jornada[/b]\nSin mejoras registradas. El desarrollo es gradual: no todos mejoran cada jornada y nadie pasa de su techo."
	else:
		progress.text = "[b]Mejoraron en la última jornada[/b]\n%s" % "\n".join(improved)

	if youth_list.item_count > 0:
		youth_list.select(0)
		_on_selected(0)
	else:
		detail.text = "No hay juveniles en la cantera."


func _on_selected(index: int) -> void:
	var pid: String = youth_list.get_item_metadata(index)
	var club := GameState.player_club
	var p := club.get_youth_player(pid)
	if p == null:
		return
	var cap := p.potential_cap()
	detail.text = "[b]%s[/b] · %d años — %s\nOVR actual %d · %s\nAtaque %d · Defensa %d · Medio %d\nFísico %d · Velocidad %d · Fuerza %d · Talento %d\nEstado: %s\nSueldo %s/jornada · Valor %s\nMargen de mejora: %d puntos" % [
		p.display_name(), p.age, p.position_label(),
		p.overall(), Youth.scouting_estimate(club, p),
		p.attack, p.defense, p.midfield,
		p.physical, p.speed, p.strength, p.talent,
		p.injury_label(),
		_money(p.salary), _money(p.value),
		maxi(0, cap - p.overall()),
	]


func _on_promote() -> void:
	var sel := youth_list.get_selected_items()
	if sel.is_empty():
		status.text = "Selecciona un juvenil."
		return
	var pid: String = youth_list.get_item_metadata(sel[0])
	status.text = Youth.promote(GameState.player_club, pid)
	GameState.save_game()
	GameState.state_changed.emit()
	_populate()


func _on_ask_plan() -> void:
	var advice: Dictionary = Youth.suggest_plan(GameState.player_club)
	plan_advice.text = str(advice.get("text", ""))
	if bool(advice.get("ok", false)):
		_select_plan(str(advice["plan_id"]))


func _on_set_plan() -> void:
	if plan_pick.selected < 0:
		return
	var plan_id: String = str(plan_pick.get_item_metadata(plan_pick.selected))
	status.text = Youth.set_plan(GameState.player_club, plan_id)
	GameState.save_game()
	_populate()


func _select_plan(plan_id: String) -> void:
	if plan_id == "":
		return
	for i in plan_pick.item_count:
		if str(plan_pick.get_item_metadata(i)) == plan_id:
			plan_pick.select(i)
			return


func _money(n: int) -> String:
	return GameState.format_money(n)
