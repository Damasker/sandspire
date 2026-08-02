extends Node2D
## Bootstrap: factions, worm, eco, FoW, pathfinding, combat, missions (S13–S14).

const SaveGameScript := preload("res://scripts/save_game.gd")
const CampaignDB := preload("res://scripts/campaign_db.gd")
const Locale := preload("res://scripts/locale.gd")
const Version := preload("res://scripts/version.gd")

@onready var world_map: Node2D = $WorldMap
@onready var camera: Camera2D = $RtsCamera
@onready var units: Node2D = $Units
@onready var buildings: Node2D = $Buildings
@onready var selection: Node2D = $SelectionController
@onready var build_controller: Node2D = $BuildController
@onready var hud: CanvasLayer = $HUD
@onready var economy: Node = $Economy
@onready var power_grid: Node = $PowerGrid
@onready var enemy_economy: Node = $EnemyEconomy
@onready var enemy_power: Node = $EnemyPowerGrid
@onready var vision: Node = $VisionSystem
@onready var pathfinder: Node = $Pathfinder
@onready var mission: Node = $Mission
@onready var ai: Node = $AiController
@onready var skirmish: Node = $SkirmishConfig
@onready var sandworm: Node2D = $Sandworm
@onready var telemetry: Node = $CombatTelemetry
@onready var save_game: Node = $SaveGame
@onready var game_options: Node = $GameOptions
@onready var sfx: Node = $SfxBus

var _ui_scale: float = 1.0
var _base_font_sizes: Dictionary = {}


func _ready() -> void:
	if skirmish == null:
		push_error("Main: SkirmishConfig missing")
		return
	if skirmish.want_campaign_menu:
		return
	if world_map == null or economy == null or power_grid == null or mission == null or hud == null or units == null or buildings == null:
		push_error("Main: critical node missing — abort spawn")
		return
	if world_map.has_signal("map_ready"):
		world_map.map_ready.connect(_on_map_ready)
	else:
		_on_map_ready(world_map.map_size_px())
	if economy.has_signal("credits_changed"):
		economy.credits_changed.connect(_on_credits_changed)
	if power_grid.has_signal("power_changed"):
		power_grid.power_changed.connect(_on_power_changed)
	if mission.has_signal("mission_complete"):
		mission.mission_complete.connect(_on_mission_complete)
	if mission.has_signal("mission_won"):
		mission.mission_won.connect(_on_mission_won)
	if mission.has_signal("mission_lost"):
		mission.mission_lost.connect(_on_mission_lost)
	if mission.has_signal("objectives_changed"):
		mission.objectives_changed.connect(_refresh_objectives_hud)
	_spawn_starting_base()
	_spawn_enemy_camp()
	_spawn_demo_units()
	var start_c := 0
	if mission.has_method("starting_credits"):
		start_c = int(mission.starting_credits())
	if start_c > 0:
		economy.add_credits(start_c)
	power_grid.recalculate()
	if enemy_power and enemy_power.has_method("recalculate"):
		enemy_power.recalculate()
	vision.update_vision()
	if pathfinder and pathfinder.has_method("rebuild_blocked"):
		pathfinder.rebuild_blocked()
	if selection.has_signal("selection_updated"):
		selection.selection_updated.connect(_on_selection_updated)
	var menu := hud.get_node_or_null("BuildMenu")
	if menu and menu.has_signal("status_message"):
		menu.status_message.connect(_set_hud_status)
	_on_credits_changed(economy.credits)
	_on_power_changed(power_grid.produced, power_grid.consumed, power_grid.surplus)
	if ai:
		ai.profile_id = skirmish.difficulty
		if ai.has_method("_load_profile"):
			ai._load_profile()
		ai.enabled = _want_skirmish_ai()
		if "faction_id" in ai:
			ai.faction_id = skirmish.enemy_faction
	if sandworm:
		sandworm.enabled = _want_worm()
	if telemetry and telemetry.has_signal("stats_updated"):
		telemetry.stats_updated.connect(_on_army_stats)
		telemetry.refresh()
	_apply_faction_hud()
	_refresh_objectives_hud()
	_show_version_badge()
	var status_title: String = str(mission.title()) if mission.has_method("title") else "Skirmish"
	_set_hud_status(
		"%s — %s vs %s (%s)"
		% [
			status_title,
			FactionDatabase.short_name(skirmish.player_faction),
			FactionDatabase.short_name(skirmish.enemy_faction),
			skirmish.difficulty,
		]
	)
	# Deferred: apply pending save, then optional briefing
	call_deferred("_post_spawn_setup")


func _show_version_badge() -> void:
	if hud == null:
		return
	var hint := hud.get_node_or_null("HelpHint") as Label
	if hint:
		hint.text = "%s  ·  %s" % [Locale.t("help_hint"), Version.short_string()]


func _post_spawn_setup() -> void:
	if save_game and not SaveGameScript.pending_load.is_empty():
		save_game.apply_pending_load()
		_refresh_objectives_hud()
		_on_credits_changed(economy.credits)
	_maybe_show_briefing()


func _want_skirmish_ai() -> bool:
	for a in OS.get_cmdline_args():
		var s := String(a)
		if s.contains("smoke_ai"):
			return true
		if s.contains("smoke_"):
			return false
	if mission.has_method("want_ai"):
		return mission.want_ai()
	return true


func _want_worm() -> bool:
	for a in OS.get_cmdline_args():
		var s := String(a)
		if s.contains("smoke_worm"):
			return true
		if s.contains("smoke_"):
			return false
	if mission.has_method("want_worm"):
		return mission.want_worm()
	return true


func _is_smoke() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	for a in OS.get_cmdline_args():
		if String(a).contains("smoke_"):
			return true
	return false


func _maybe_show_briefing() -> void:
	if _is_smoke():
		return
	if not mission.has_method("has_briefing") or not mission.has_briefing():
		return
	var panel := hud.get_node_or_null("AdvisorPanel")
	if panel and panel.has_method("show_briefing"):
		panel.show_briefing(
			mission.title(),
			mission.briefing_advisor(),
			mission.briefing_text(),
			mission.objective_lines()
		)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var is_help: bool = (
			event.keycode == KEY_F1
			or event.unicode == 63
			or (event.keycode == KEY_SLASH and event.shift_pressed)
		)
		if is_help:
			var help := hud.get_node_or_null("HelpOverlay")
			if help and help.has_method("toggle"):
				help.toggle()
			get_viewport().set_input_as_handled()
			return
		match event.keycode:
			KEY_B:
				_toggle_advisor()
				get_viewport().set_input_as_handled()
			KEY_O:
				var op := hud.get_node_or_null("OptionsPanel")
				if op and op.has_method("toggle"):
					op.toggle(game_options)
				get_viewport().set_input_as_handled()
			KEY_F5:
				if save_game:
					save_game.save_autosave()
					_set_hud_status(Locale.t("autosave_ok"))
					if sfx:
						sfx.play_ui("ok")
				get_viewport().set_input_as_handled()
			KEY_F9:
				if save_game:
					if save_game.load_autosave():
						_set_hud_status(Locale.t("autoload_ok"))
						_refresh_objectives_hud()
						if sfx:
							sfx.play_ui("ok")
					else:
						_set_hud_status(Locale.t("autoload_miss"))
						if sfx:
							sfx.play_ui("warn")
				get_viewport().set_input_as_handled()


func apply_ui_scale(scale: float) -> void:
	_ui_scale = clampf(scale, 0.85, 1.5)
	if hud == null:
		return
	for path in ["Status", "Power", "Army", "Credits", "Objectives", "HelpHint", "Victory", "Defeat"]:
		var lab := hud.get_node_or_null(path) as Label
		if lab == null:
			continue
		if not _base_font_sizes.has(path):
			var cur := lab.get_theme_font_size("font_size")
			_base_font_sizes[path] = cur if cur > 0 else 16
		lab.add_theme_font_size_override("font_size", int(round(float(_base_font_sizes[path]) * _ui_scale)))
	var menu := hud.get_node_or_null("BuildMenu")
	if menu and menu.has_method("apply_ui_scale"):
		menu.apply_ui_scale(_ui_scale)


func refresh_locale_hud() -> void:
	if hud == null:
		return
	_show_version_badge()
	if economy:
		_on_credits_changed(economy.credits)
	if power_grid:
		_on_power_changed(power_grid.produced, power_grid.consumed, power_grid.surplus)
	if telemetry and telemetry.has_method("refresh"):
		telemetry.refresh()
	_refresh_objectives_hud()
	var menu := hud.get_node_or_null("BuildMenu")
	if menu and menu.has_method("refresh_locale"):
		menu.refresh_locale()
	var help := hud.get_node_or_null("HelpOverlay")
	if help and help.has_method("refresh_text"):
		help.refresh_text()
	var op := hud.get_node_or_null("OptionsPanel")
	if op and op.has_method("refresh_labels"):
		op.refresh_labels()


func _toggle_advisor() -> void:
	var panel := hud.get_node_or_null("AdvisorPanel")
	if panel == null:
		return
	if panel.visible:
		panel.hide_panel()
	elif mission.has_method("has_briefing"):
		panel.show_advisor(
			mission.title(),
			mission.briefing_advisor() if mission.has_briefing() else "Advisor",
			mission.briefing_text() if mission.has_briefing() else "No briefing for this skirmish.",
			mission.objective_lines()
		)


func _apply_faction_hud() -> void:
	var accent := FactionDatabase.accent_color(skirmish.player_faction)
	var status := hud.get_node_or_null("Status") as Label
	if status:
		status.modulate = accent.lightened(0.35)
	var panel := hud.get_node_or_null("Panel") as ColorRect
	if panel:
		panel.color = Color(0.1, 0.08, 0.06, 0.8)
	var menu := hud.get_node_or_null("BuildMenu")
	if menu and menu.has_method("set_faction_theme"):
		menu.set_faction_theme(skirmish.player_faction)


func _on_map_ready(size_px: Vector2) -> void:
	if camera.has_method("configure_bounds"):
		camera.configure_bounds(size_px)
	camera.global_position = Vector2(560, 560)


func _spawn_starting_base() -> void:
	_spawn_building("b_conyard", Vector2i(12, 14), Color(0.35, 0.45, 0.55), GameConstants.Team.PLAYER)
	_spawn_building("b_power", Vector2i(16, 14), Color(0.45, 0.65, 0.85), GameConstants.Team.PLAYER)
	_spawn_building("b_refinery", Vector2i(20, 18), Color(0.5, 0.4, 0.28), GameConstants.Team.PLAYER)


func _spawn_enemy_camp() -> void:
	var params: Dictionary = mission.map_params() if mission.has_method("map_params") else {}
	var tag_base := bool(params.get("tag_enemy_base", false))
	var force := str(params.get("enemy_force", "standard"))
	var camp := _spawn_building("b_camp", Vector2i(34, 8), Color(0.7, 0.22, 0.18), GameConstants.Team.ENEMY)
	mission.register_camp(camp)
	var cy := _spawn_building("b_conyard", Vector2i(37, 10), Color(0.55, 0.28, 0.25), GameConstants.Team.ENEMY)
	var pwr := _spawn_building("b_power", Vector2i(35, 12), Color(0.6, 0.3, 0.35), GameConstants.Team.ENEMY)
	if tag_base:
		if camp:
			camp.add_to_group("enemy_base")
		if cy:
			cy.add_to_group("enemy_base")
	if enemy_power:
		if cy and enemy_power.has_method("register_building"):
			enemy_power.register_building(cy)
		if pwr and enemy_power.has_method("register_building"):
			enemy_power.register_building(pwr)
		if camp and enemy_power.has_method("register_building"):
			enemy_power.register_building(camp)
	var inf := FactionDatabase.role_unit(skirmish.enemy_faction, "infantry")
	var quad := FactionDatabase.role_unit(skirmish.enemy_faction, "quad")
	var tank := FactionDatabase.role_unit(skirmish.enemy_faction, "tank")
	if inf == "":
		inf = "u_infantry"
	if quad == "":
		quad = "u_quad"
	if tank == "":
		tank = "u_tank"
	var specs: Array = [{"id": inf, "pos": Vector2(33 * 32 + 16, 11 * 32)}]
	if force != "light":
		specs.append({"id": quad, "pos": Vector2(36 * 32, 10 * 32 + 8)})
	if force == "heavy":
		specs.append({"id": tank, "pos": Vector2(35 * 32, 9 * 32 + 16)})
		specs.append({"id": inf, "pos": Vector2(34 * 32, 12 * 32)})
	var unit_scene := preload("res://scenes/unit.tscn")
	for spec in specs:
		var u: CharacterBody2D = unit_scene.instantiate()
		u.unit_id = spec["id"]
		u.team = GameConstants.Team.ENEMY
		u.team_color = Color(0.85, 0.25, 0.2)
		u.auto_acquire = true
		u.global_position = spec["pos"]
		units.add_child(u)


func _spawn_building(building_id: String, origin: Vector2i, color: Color, team: int) -> Node:
	var scene := preload("res://scenes/building.tscn")
	var b: StaticBody2D = scene.instantiate()
	b.building_id = building_id
	b.footprint = BuildingDatabase.footprint_of(building_id)
	b.team_color = color
	b.team = team
	b.global_position = Vector2(
		origin.x * GameConstants.TILE_SIZE,
		origin.y * GameConstants.TILE_SIZE
	)
	buildings.add_child(b)
	if team == GameConstants.Team.PLAYER:
		power_grid.register_building(b)
	return b


func _spawn_demo_units() -> void:
	var pf: String = skirmish.player_faction
	var params: Dictionary = mission.map_params() if mission.has_method("map_params") else {}
	var force := str(params.get("player_force", "standard"))
	var trike := FactionDatabase.role_unit(pf, "trike")
	var infantry := FactionDatabase.role_unit(pf, "infantry")
	var harv := FactionDatabase.role_unit(pf, "harvester")
	var tank := FactionDatabase.role_unit(pf, "tank")
	if trike == "":
		trike = "u_trike"
	if infantry == "":
		infantry = "u_infantry"
	if harv == "":
		harv = "u_harvester"
	if tank == "":
		tank = "u_tank"
	var combat: Array = [{"id": trike, "pos": Vector2(420, 420)}]
	if force != "tutorial":
		combat.append({"id": infantry, "pos": Vector2(440, 500)})
	if force == "raid":
		combat.append({"id": trike, "pos": Vector2(400, 460)})
	if force == "siege":
		var siege := FactionDatabase.role_unit(pf, "siege")
		if siege == "":
			siege = "u_siege"
		combat.append({"id": tank, "pos": Vector2(400, 480)})
		combat.append({"id": siege, "pos": Vector2(380, 520)})
	var unit_scene := preload("res://scenes/unit.tscn")
	for spec in combat:
		var u: CharacterBody2D = unit_scene.instantiate()
		u.unit_id = spec["id"]
		u.team = GameConstants.Team.PLAYER
		u.global_position = spec["pos"]
		units.add_child(u)

	var harv_scene := preload("res://scenes/harvester.tscn")
	var h: CharacterBody2D = harv_scene.instantiate()
	h.unit_id = harv
	h.global_position = Vector2(24 * GameConstants.TILE_SIZE, 20 * GameConstants.TILE_SIZE)
	h.team = GameConstants.Team.PLAYER
	units.add_child(h)


func _on_selection_updated(count: int) -> void:
	var waves := 0
	if ai:
		waves = int(ai.get("waves_launched"))
	var mid := str(skirmish.mission_id) if skirmish.mission_id != "" else "skirmish"
	_set_hud_status(
		"Selected: %d  |  %s  |  %s vs %s  |  waves %d"
		% [
			count,
			mid,
			FactionDatabase.short_name(skirmish.player_faction),
			FactionDatabase.short_name(skirmish.enemy_faction),
			waves,
		]
	)


func _on_army_stats(pc: int, pv: int, ec: int, ev: int) -> void:
	var label := hud.get_node_or_null("Army") as Label
	if label:
		label.text = Locale.t("army") % [pc, pv, ec, ev]


func _refresh_objectives_hud() -> void:
	var label := hud.get_node_or_null("Objectives") as Label
	if label == null or not mission.has_method("objective_lines"):
		return
	var header := Locale.t("objectives")
	var lines: PackedStringArray = mission.objective_lines()
	if lines.is_empty():
		label.text = header
	else:
		label.text = header + "\n" + "\n".join(lines)


func _on_credits_changed(credits: int) -> void:
	var label := hud.get_node_or_null("Credits") as Label
	if label:
		var cap := int(economy.credit_cap) if economy else 0
		if economy and economy.has_method("recalculate_cap"):
			economy.recalculate_cap()
			cap = int(economy.credit_cap)
		label.text = Locale.t("credits") % [credits, cap]
	_refresh_objectives_hud()


func _on_power_changed(produced: int, consumed: int, surplus: int) -> void:
	var label := hud.get_node_or_null("Power") as Label
	if label == null:
		return
	if surplus < 0:
		label.text = Locale.t("power_low") % [produced, consumed]
		label.modulate = Color(1.0, 0.4, 0.35)
	else:
		label.text = Locale.t("power") % [surplus, produced, consumed]
		label.modulate = Color(0.75, 0.95, 1.0)


func _on_mission_complete() -> void:
	# M1 compat; prefer mission_won for banner + autosave when available.
	if mission.failed:
		return
	if mission.has_signal("mission_won"):
		return
	var text := str(mission.outcome_text) if str(mission.outcome_text) != "" else "Victory"
	_show_outcome(true, text)


func _on_mission_won(text: String) -> void:
	var banner := text
	if skirmish.campaign_id != "" and mission.mission_id != "":
		var next_id := CampaignDB.mark_won(skirmish.campaign_id, mission.mission_id)
		if next_id != "":
			var ndef := CampaignDB.load_mission_def(next_id)
			banner = "%s  |  Next unlocked: %s" % [text, str(ndef.get("title", next_id))]
		else:
			banner = "%s  |  Campaign complete" % text
	_show_outcome(true, banner)
	if save_game and save_game.has_method("save_autosave"):
		save_game.save_autosave()


func _on_mission_lost(text: String) -> void:
	_show_outcome(false, text)


func _show_outcome(won: bool, text: String) -> void:
	_set_hud_status(text)
	var victory := hud.get_node_or_null("Victory") as Label
	var defeat := hud.get_node_or_null("Defeat") as Label
	var prefix := Locale.t("victory") if won else Locale.t("defeat")
	var banner := text if text.begins_with(prefix) else "%s — %s" % [prefix, text]
	if won:
		if victory:
			victory.visible = true
			victory.text = banner
		if defeat:
			defeat.visible = false
		if sfx:
			sfx.play_ui("win")
	else:
		if defeat:
			defeat.visible = true
			defeat.text = banner
		if victory:
			victory.visible = false
		if sfx:
			sfx.play_ui("warn")
	_refresh_objectives_hud()


func _set_hud_status(text: String) -> void:
	var label := hud.get_node_or_null("Status") as Label
	if label:
		label.text = text
