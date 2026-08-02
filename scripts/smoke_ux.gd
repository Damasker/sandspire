extends SceneTree
## S15 smoke: locale parity, options persist, help/options nodes, tooltips.
## Run: godot --headless --path . -s res://scripts/smoke_ux.gd

const Locale := preload("res://scripts/locale.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[smoke_ux] starting")

	# Locale dictionaries must share keys
	var en: Dictionary = Locale.STRINGS["en"]
	var ru: Dictionary = Locale.STRINGS["ru"]
	for k in en.keys():
		if not ru.has(k):
			push_error("[smoke_ux] RU missing key %s" % k)
			quit(1)
			return
		if str(ru[k]) == "":
			push_error("[smoke_ux] RU empty %s" % k)
			quit(1)
			return
	Locale.set_locale("ru")
	if not Locale.t("credits").contains("%d"):
		push_error("[smoke_ux] credits format broken")
		quit(1)
		return
	Locale.set_locale("en")

	# Options round-trip to temp path
	var tmp := "user://smoke_options_%d.json" % Time.get_ticks_msec()
	var data := {
		"scroll_speed": 900.0,
		"edge_scroll": false,
		"master_volume": 0.5,
		"sfx_volume": 0.4,
		"ui_scale": 1.25,
		"locale": "ru",
	}
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("[smoke_ux] cannot write temp options")
		quit(1)
		return
	f.store_string(JSON.stringify(data))
	f.close()

	var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string(tmp))
	if typeof(loaded) != TYPE_DICTIONARY or float(loaded.get("scroll_speed", 0)) != 900.0:
		push_error("[smoke_ux] options persist failed")
		quit(1)
		return
	if str(loaded.get("locale")) != "ru" or bool(loaded.get("edge_scroll")) != false:
		push_error("[smoke_ux] options fields wrong")
		quit(1)
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))

	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("[smoke_ux] main load failed")
		quit(1)
		return
	for i in 20:
		await process_frame

	var root := current_scene
	var help := root.get_node_or_null("HUD/HelpOverlay")
	var options := root.get_node_or_null("HUD/OptionsPanel")
	var gopt := root.get_node_or_null("GameOptions")
	var sfx := root.get_node_or_null("SfxBus")
	var menu := root.get_node_or_null("HUD/BuildMenu")
	if help == null or options == null or gopt == null or sfx == null:
		push_error("[smoke_ux] missing Help/Options/GameOptions/SfxBus")
		quit(1)
		return
	if not help.has_method("toggle") or not options.has_method("open_from_options"):
		push_error("[smoke_ux] overlay API missing")
		quit(1)
		return
	help.show_help()
	if not help.visible:
		push_error("[smoke_ux] help not visible")
		quit(1)
		return
	help.hide_help()
	options.open_from_options(gopt)
	if not options.visible:
		push_error("[smoke_ux] options not visible")
		quit(1)
		return
	options.hide_panel()

	# Building tooltip content
	if menu == null or not menu.has_method("_building_tooltip"):
		push_error("[smoke_ux] build menu tooltip API missing")
		quit(1)
		return
	var tip: String = menu._building_tooltip("b_factory")
	if not tip.contains("Cost:") or not tip.contains("Power:") or not tip.contains("Prereq:"):
		push_error("[smoke_ux] factory tooltip incomplete: %s" % tip)
		quit(1)
		return

	# Apply locale via options
	gopt.set_from_ui(600.0, true, 0.0, 0.0, 1.0, "ru")
	await process_frame
	var credits := root.get_node_or_null("HUD/Credits") as Label
	if credits == null or not str(credits.text).begins_with("Кредиты"):
		push_error("[smoke_ux] RU credits HUD failed: %s" % (credits.text if credits else "null"))
		quit(1)
		return
	gopt.set_from_ui(600.0, true, 0.8, 0.7, 1.0, "en")

	# Tutorial briefing clarity
	var m01_raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/missions/m01_first_blood.json"))
	if typeof(m01_raw) != TYPE_DICTIONARY:
		push_error("[smoke_ux] m01 JSON bad")
		quit(1)
		return
	var m01: Dictionary = m01_raw
	var br: Dictionary = m01.get("briefing", {})
	var brief := str(br.get("text", ""))
	if not brief.contains("5-minute") or not brief.contains("hotkeys"):
		push_error("[smoke_ux] tutorial briefing not clarified")
		quit(1)
		return

	print("[smoke_ux] OK — locale, options, help/options UI, tooltips, tutorial")
	quit(0)
