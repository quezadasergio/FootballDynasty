extends Control

const ClubFinance = preload("res://scripts/core/club_finance.gd")

@onready var body: RichTextLabel = $Margin/Scroll/VBox/Body


func _ready() -> void:
	$Margin/Scroll/VBox/BtnContinue.pressed.connect(_on_continue)
	_fill()


func _fill() -> void:
	var f: Dictionary = GameState.last_matchday_finance
	if f.is_empty():
		body.text = "Sin resumen financiero de la jornada."
		return

	var amounts: Dictionary = f.get("contract_amounts", {})
	var partners: Dictionary = f.get("contract_partners", {})

	var text := "[b]Ganancias y pérdidas — %s[/b]\n%s\n\n" % [
		str(f.get("league_name", "")),
		"Liga MX" if int(f.get("tier", 2)) <= 1 else "Expansión MX",
	]

	text += "[b]Ingresos del partido[/b] (ya cobrados al finalizar)\n"
	text += "  Entradas / taquilla:  %s\n" % _money(int(f.get("gate", 0)))
	text += "  Premio por resultado: %s\n" % _money(int(f.get("prize", 0)))
	text += "  Subtotal partido:     %s\n\n" % _money(int(f.get("match_income_total", 0)))

	for group in ClubFinance.CONTRACT_GROUPS:
		text += "[b]%s[/b]\n" % str(group["label"])
		for type_key in group["types"]:
			var key := str(type_key)
			text += "  %s (%s): %s\n" % [
				ClubFinance.type_label(key),
				str(partners.get(key, "")),
				_money(int(amounts.get(key, 0))),
			]
		text += "\n"
	text += "  Subtotal contratos: %s\n\n" % _money(int(f.get("media_total", 0)))

	var transfers_in: int = int(f.get("transfers_in", 0))
	var transfers_out: int = int(f.get("transfers_out", 0))
	if transfers_in > 0 or transfers_out > 0:
		var net_tr: int = int(f.get("transfers_net", 0))
		var tr_color := "green" if net_tr >= 0 else "red"
		text += "[b]Mercado de transferencias[/b]\n"
		text += "  Ventas cobradas:   %s\n" % _money(transfers_in)
		text += "  Compras pagadas:   %s\n" % _money(transfers_out)
		text += "  Saldo del mercado: [color=%s]%s[/color]\n\n" % [tr_color, _money(net_tr)]

	text += "[b]Gastos[/b]\n"
	text += "  Sueldos jugadores: %s\n" % _money(int(f.get("player_wages", 0)))
	text += "  Sueldos staff:     %s\n" % _money(int(f.get("staff_wages", 0)))
	text += "  Sueldos juveniles: %s\n" % _money(int(f.get("youth_wages", 0)))
	text += "  Academia:          %s\n" % _money(int(f.get("academy_cost", 0)))
	var medical: int = int(f.get("medical_cost", 0))
	if medical > 0:
		text += "  Cirugías y tratamientos: %s\n" % _money(medical)
	var facilities: int = int(f.get("facilities_cost", 0))
	if facilities > 0:
		text += "  Obras del estadio: %s\n" % _money(facilities)
	if transfers_out > 0:
		text += "  Fichajes:          %s\n" % _money(transfers_out)
	if int(f.get("loan_payment", 0)) > 0 or int(f.get("loan_remaining", 0)) > 0:
		text += "  Pago préstamo dueño: %s  (resta %s)\n" % [
			_money(int(f.get("loan_payment", 0))), _money(int(f.get("loan_remaining", 0)))
		]
	text += "  Subtotal gastos:   %s\n\n" % _money(int(f.get("expense_total", 0)))

	var net: int = int(f.get("net", 0))
	var net_color := "green" if net >= 0 else "red"
	text += "────────────────────────\n"
	text += "Ingresos totales: %s\n" % _money(int(f.get("income_total", 0)))
	text += "Gastos totales:   %s\n" % _money(int(f.get("expense_total", 0)))
	text += "Balance de la jornada: [color=%s]%s[/color]\n\n" % [net_color, _money(net)]
	text += "Presupuesto antes de liquidar: %s\n" % _money(int(f.get("budget_before", 0)))
	text += "Presupuesto actual: [b]%s[/b]" % _money(int(f.get("budget_after", 0)))

	var medical_report: Dictionary = GameState.last_matchday_medical
	var recovered: Array = medical_report.get("recovered", [])
	var relapsed: Array = medical_report.get("relapsed", [])
	if not recovered.is_empty() or not relapsed.is_empty():
		text += "\n\n[b]Parte médico de la jornada[/b]\n"
		if not recovered.is_empty():
			text += "  Altas: %s\n" % ", ".join(recovered)
		if not relapsed.is_empty():
			text += "  [color=red]Recaídas: %s[/color]\n" % ", ".join(relapsed)

	body.text = text


func _on_continue() -> void:
	get_tree().change_scene_to_file("res://scenes/office/matchday_results.tscn")


func _money(n: int) -> String:
	return GameState.format_money(n)
