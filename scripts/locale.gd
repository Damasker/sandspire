extends RefCounted
## Simple EN/RU dictionary for key HUD strings (S15).

const STRINGS := {
	"en": {
		"credits": "Credits: %d / %d",
		"power": "Power: %+d (%d/%d)",
		"power_low": "Power: %d/%d LOW",
		"objectives": "Objectives",
		"victory": "Victory",
		"defeat": "Defeat",
		"army": "Army P:%d/%d  E:%d/%d",
		"help_title": "Hotkeys",
		"options_title": "Options",
		"autosave_ok": "Autosave written (F5)",
		"autoload_ok": "Autosave loaded (F9)",
		"autoload_miss": "No autosave found",
		"locale_name": "English",
		"scroll_speed": "Scroll speed",
		"edge_scroll": "Edge scroll",
		"master_volume": "Master volume",
		"sfx_volume": "SFX volume",
		"ui_scale": "UI font scale",
		"language": "Language",
		"apply": "Apply",
		"close": "Close",
		"build_title": "Build (1-6)",
		"produce_title": "Produce (Q–Y)",
		"power_ok": "Power OK",
		"help_hint": "? / F1 help   O options   B advisor",
	},
	"ru": {
		"credits": "Кредиты: %d / %d",
		"power": "Энергия: %+d (%d/%d)",
		"power_low": "Энергия: %d/%d МАЛО",
		"objectives": "Цели",
		"victory": "Победа",
		"defeat": "Поражение",
		"army": "Армия И:%d/%d  В:%d/%d",
		"help_title": "Клавиши",
		"options_title": "Настройки",
		"autosave_ok": "Автосохранение (F5)",
		"autoload_ok": "Загрузка (F9)",
		"autoload_miss": "Нет автосохранения",
		"locale_name": "Русский",
		"scroll_speed": "Скорость камеры",
		"edge_scroll": "Край экрана",
		"master_volume": "Общая громкость",
		"sfx_volume": "Эффекты",
		"ui_scale": "Масштаб UI",
		"language": "Язык",
		"apply": "Применить",
		"close": "Закрыть",
		"build_title": "Строить (1-6)",
		"produce_title": "Производство (Q–Y)",
		"power_ok": "Энергия OK",
		"help_hint": "? / F1 справка   O настройки   B советник",
	},
}

static var locale: String = "en"


static func set_locale(code: String) -> void:
	var c := code.to_lower()
	if STRINGS.has(c):
		locale = c
	else:
		locale = "en"


static func t(key: String, default_text: String = "") -> String:
	var table: Dictionary = STRINGS.get(locale, STRINGS["en"])
	if table.has(key):
		return str(table[key])
	var en: Dictionary = STRINGS["en"]
	if en.has(key):
		return str(en[key])
	return default_text if default_text != "" else key


static func has_key(key: String) -> bool:
	return STRINGS["en"].has(key)


static func required_keys() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for k in STRINGS["en"].keys():
		out.append(str(k))
	return out
