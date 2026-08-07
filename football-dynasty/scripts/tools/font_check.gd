extends SceneTree

func _initialize() -> void:
	var theme_path: String = ProjectSettings.get_setting("gui/theme/custom", "")
	print("theme=", theme_path)
	var theme: Theme = load(theme_path)
	if theme == null:
		print("FAIL: no se pudo cargar el tema")
		quit(1)
		return
	var checks := {
		"flecha atras U+2190": 0x2190,
		"flecha derecha U+2192": 0x2192,
		"estrella U+2605": 0x2605,
		"punto medio U+00B7": 0x00B7,
		"vineta U+2022": 0x2022,
		"raya U+2500": 0x2500,
		"acento U+00E1": 0x00E1,
		"enie U+00F1": 0x00F1,
	}
	var fonts := {
		"default": theme.default_font,
		"RichTextLabel bold": theme.get_font("bold_font", "RichTextLabel"),
	}
	var failures := 0
	for fname in fonts.keys():
		var font: Font = fonts[fname]
		if font == null:
			print("FAIL: fuente nula -> ", fname)
			failures += 1
			continue
		for label in checks.keys():
			if not font.has_char(int(checks[label])):
				print("FAIL: ", fname, " sin glifo ", label)
				failures += 1
		print(fname, " -> ", font.get_font_name(), " glifos verificados")
	if failures == 0:
		print("=== FUENTES OK ===")
	quit(failures)
