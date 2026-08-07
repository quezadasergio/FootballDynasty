extends Control

const Contracts = preload("res://scripts/core/contract_service.gd")
const StaffScript = preload("res://scripts/core/staff_member.gd")

@onready var info: Label = $Margin/Scroll/HBox/Left/Info
@onready var player_list: ItemList = $Margin/Scroll/HBox/Left/PlayerList
@onready var detail: RichTextLabel = $Margin/Scroll/HBox/Left/Detail
@onready var status: Label = $Margin/Scroll/HBox/Left/Status
@onready var years_box: SpinBox = $Margin/Scroll/HBox/Right/YearsRow/Years
@onready var annual_box: SpinBox = $Margin/Scroll/HBox/Right/AnnualRow/Annual
@onready var bonus_box: SpinBox = $Margin/Scroll/HBox/Right/BonusRow/Bonus
@onready var cost: RichTextLabel = $Margin/Scroll/HBox/Right/Cost
@onready var advisor: RichTextLabel = $Margin/Scroll/HBox/Right/Advisor
@onready var btn_list: Button = $Margin/Scroll/HBox/Right/BtnList
@onready var btn_release: Button = $Margin/Scroll/HBox/Right/BtnRelease
@onready var btn_cancel_transfer: Button = $Margin/Scroll/HBox/Right/BtnCancelTransfer

## "" = fichaje pendiente; en otro caso, id del jugador de la plantilla.
var _selected_id: String = ""
var _is_pending_signing: bool = false


func _ready() -> void:
	$Margin/Scroll/HBox/Right/BtnMatchDemands.pressed.connect(_on_match_demands)
	$Margin/Scroll/HBox/Right/BtnOffer.pressed.connect(_on_offer)
	$Margin/Scroll/HBox/Right/BtnAdvisor.pressed.connect(_on_advisor)
	btn_list.pressed.connect(_on_toggle_listed)
	btn_release.pressed.connect(_on_release)
	btn_cancel_transfer.pressed.connect(_on_cancel_transfer)
	player_list.item_selected.connect(_on_select)
	years_box.value_changed.connect(func(_v): _refresh_cost())
	annual_box.value_changed.connect(func(_v): _refresh_cost())
	bonus_box.value_changed.connect(func(_v): _refresh_cost())
	_populate()


func _populate() -> void:
	var club := GameState.player_club
	player_list.clear()
	if club == null:
		info.text = "Sin club."
		return

	var pending := GameState.pending_transfer_player()
	if pending != null:
		player_list.add_item("★ FICHAJE PENDIENTE · %s %s (%d) — sin contrato" % [
			pending.position_label(), pending.display_name(), pending.overall()
		])
		player_list.set_item_custom_fg_color(player_list.item_count - 1, Color(1.0, 0.85, 0.35))
		player_list.set_item_metadata(player_list.item_count - 1, "")

	var sorted: Array = club.players.duplicate()
	sorted.sort_custom(func(a: Player, b: Player) -> bool:
		if a.has_contract() != b.has_contract():
			return not a.has_contract()
		if a.contract_years_left != b.contract_years_left:
			return a.contract_years_left < b.contract_years_left
		return a.overall() > b.overall()
	)
	for p in sorted:
		var tags: PackedStringArray = []
		if not p.has_contract():
			tags.append("SIN CONTRATO")
		else:
			tags.append("%d año(s)" % p.contract_years_left)
		if p.renewal_refused:
			tags.append("NO RENUEVA")
		if p.transfer_listed:
			tags.append("TRANSFERIBLE")
		player_list.add_item("%s %s (%d) · %s/año · %s" % [
			p.position_label(), p.display_name(), p.overall(),
			_money(p.annual_salary()), " · ".join(tags)
		])
		var row := player_list.item_count - 1
		player_list.set_item_metadata(row, p.id)
		if not p.has_contract():
			player_list.set_item_custom_fg_color(row, Color(1.0, 0.45, 0.4))
		elif p.contract_years_left <= 1:
			player_list.set_item_custom_fg_color(row, Color(1.0, 0.78, 0.35))

	_refresh_info()
	if player_list.item_count > 0:
		player_list.select(0)
		_on_select(0)
	else:
		detail.text = ""


func _refresh_info() -> void:
	var club := GameState.player_club
	var blockers: Array = Contracts.players_without_contract(club)
	var legal = club.get_staff(StaffScript.Role.LEGAL)
	var advisor_txt := "sin asesor legal (contrátalo en Plantilla)"
	if legal:
		advisor_txt = "asesor: %s (hab. %d)" % [legal.staff_name, legal.skill]
	var annual_bill := 0
	for p in club.players:
		annual_bill += p.annual_salary()
	info.text = "Presupuesto: %s  ·  Nómina anual del primer equipo: %s  ·  %s\nSin contrato vigente: %d  ·  Transferibles: %d" % [
		_money(club.budget), _money(annual_bill), advisor_txt,
		blockers.size(), club.transfer_listed_players().size()
	]
	btn_cancel_transfer.visible = not GameState.pending_transfer.is_empty()
	var note := GameState.contract_block_reason()
	if note != "":
		status.text = note


func _selected_player() -> Player:
	if _is_pending_signing:
		return GameState.pending_transfer_player()
	var club := GameState.player_club
	if club == null or _selected_id == "":
		return null
	return club.get_player(_selected_id)


func _on_select(index: int) -> void:
	var meta = player_list.get_item_metadata(index)
	_selected_id = str(meta) if meta != null else ""
	_is_pending_signing = _selected_id == ""
	var p := _selected_player()
	if p == null:
		detail.text = ""
		return
	var club := GameState.player_club
	var offer: Dictionary = Contracts.default_offer(p, club)
	years_box.value = float(offer["years"])
	annual_box.value = float(offer["annual"])
	bonus_box.value = float(offer["bonus"])
	_fill_detail(p)
	_refresh_cost()
	advisor.text = ""
	btn_list.text = "Quitar de transferibles" if p.transfer_listed else "Poner en transferibles"
	btn_list.disabled = _is_pending_signing
	btn_release.disabled = _is_pending_signing


func _fill_detail(p: Player) -> void:
	var club := GameState.player_club
	var lines: PackedStringArray = []
	lines.append("[b]%s[/b] · %s · %d años · OVR %d" % [
		p.display_name(), p.position_label(), p.age, p.overall()
	])
	if _is_pending_signing:
		lines.append("[color=yellow]Traspaso ya pagado (%s). Falta firmar contrato.[/color]" % _money(int(GameState.pending_transfer.get("price", 0))))
	lines.append("Contrato actual: %s" % p.contract_label())
	if p.has_contract():
		lines.append("  Sueldo: %s al año (%s por jornada)" % [_money(p.annual_salary()), _money(p.salary)])
		lines.append("  Bono cobrado al firmar: %s" % _money(p.contract_signing_bonus))
		var cost_out := Contracts.release_cost(p)
		if cost_out > 0:
			lines.append("  Rescindir costaría: %s" % _money(cost_out))
	else:
		lines.append("  [color=red]No puede seguir en el club sin contrato.[/color]")
	if p.renewal_refused:
		lines.append("[color=orange]Se negó a renovar: no aceptará ninguna oferta.[/color]")
	if p.transfer_listed:
		lines.append("[color=orange]En la lista de transferibles.[/color]")
	lines.append("Ánimo: contento %d · moral %d · forma %d" % [p.happiness, p.morale, p.form])
	var marketing := Contracts.player_marketing_income(p, club)
	if marketing > 0:
		lines.append("Tirón comercial: %d/100 → %s por jornada en publicidad" % [p.marketability, _money(marketing)])
	else:
		lines.append("Tirón comercial: %d/100 → no aporta publicidad" % p.marketability)
	detail.text = "\n".join(lines)


func _current_offer() -> Dictionary:
	return {
		"years": int(years_box.value),
		"annual": int(annual_box.value),
		"bonus": int(bonus_box.value),
	}


func _refresh_cost() -> void:
	var p := _selected_player()
	if p == null:
		cost.text = ""
		return
	var offer := _current_offer()
	var per_md := Contracts.matchday_from_annual(int(offer["annual"]))
	cost.text = "[b]Lo que te cuesta[/b]\n  Al año: %s  (%s por jornada)\n  Bono de firma: %s\n  Primer año: [b]%s[/b]\n  Contrato completo (%d años): %s" % [
		_money(int(offer["annual"])), _money(per_md), _money(int(offer["bonus"])),
		_money(Contracts.first_year_cost(offer)), int(offer["years"]),
		_money(Contracts.total_cost(offer))
	]


func _on_match_demands() -> void:
	var p := _selected_player()
	if p == null:
		return
	var d := Contracts.demands(p, GameState.player_club)
	years_box.value = float(d["years"])
	annual_box.value = float(d["annual"])
	bonus_box.value = float(d["bonus"])
	_refresh_cost()
	status.text = "Oferta ajustada a lo que pide %s." % p.display_name()


func _on_advisor() -> void:
	var p := _selected_player()
	if p == null:
		return
	var report := Contracts.advisor_report(GameState.player_club, p, _current_offer())
	advisor.text = str(report.get("text", ""))


func _on_offer() -> void:
	var p := _selected_player()
	if p == null:
		return
	var offer := _current_offer()
	var result: Dictionary
	if _is_pending_signing:
		result = GameState.complete_pending_transfer(offer)
	else:
		result = Contracts.sign(GameState.player_club, p, offer)
	status.text = str(result.get("text", ""))
	if not bool(result.get("ok", false)):
		var ev: Dictionary = result.get("evaluation", {})
		var counter: Dictionary = ev.get("counter", {})
		if not counter.is_empty():
			advisor.text = "[b]Contraoferta del representante[/b]\n  %d años · %s al año · %s de bono\n\nPulsa «Igualar lo que pide» para aceptarla." % [
				int(counter["years"]), _money(int(counter["annual"])), _money(int(counter["bonus"]))
			]
		return
	GameState.save_game()
	_populate()


func _on_toggle_listed() -> void:
	var p := _selected_player()
	if p == null or _is_pending_signing:
		return
	status.text = Contracts.set_transfer_listed(p, not p.transfer_listed)
	GameState.save_game()
	_populate()


func _on_release() -> void:
	var p := _selected_player()
	if p == null or _is_pending_signing:
		return
	var result := Contracts.release(GameState.player_club, p, GameState.free_agents)
	status.text = str(result.get("text", ""))
	if bool(result.get("ok", false)):
		GameState.save_game()
		_populate()


func _on_cancel_transfer() -> void:
	var msg := GameState.cancel_pending_transfer()
	if msg != "":
		status.text = msg
		GameState.save_game()
		_populate()


func _money(n: int) -> String:
	return GameState.format_money(n)
