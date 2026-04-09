## LocaleManager — 多語系管理 (支援 zh_TW / en)
## Autoload 單例；使用 Godot 內建 tr() 翻譯所有 UI 文字
extends Node

signal locale_changed(locale: String)

const LOCALES   : Array[String] = ["zh_TW", "en"]
const SAVE_PATH : String        = "user://settings.cfg"
const CFG_SEC   : String        = "locale"
const CFG_KEY   : String        = "language"

var current_locale : String = "en"

# ── 翻譯表 ────────────────────────────────────────────────────────────────

const _ZH_TW : Dictionary = {
	# 季節
	"SEASON_SPRING":      "春",
	"SEASON_SUMMER":      "夏",
	"SEASON_FALL":        "秋",
	"SEASON_WINTER":      "冬",
	# HUD
	"HUD_DATE":           "%s 第%d天",
	"HUD_GOLD":           "G %d",
	# 工具
	"TOOL_HOE":           "鋤頭",
	"TOOL_WATERING_CAN":  "水壺",
	"TOOL_SEEDS":         "種子",
	# 時段
	"PERIOD_MIDNIGHT":    "深夜",
	"PERIOD_MORNING":     "早晨",
	"PERIOD_FORENOON":    "上午",
	"PERIOD_AFTERNOON":   "下午",
	"PERIOD_EVENING":     "傍晚",
	"PERIOD_NIGHT":       "夜晚",
	# 遊戲選單
	"MENU_RESUME":        "繼續遊戲",
	"MENU_SETTINGS":      "設　　定",
	"MENU_QUIT":          "離開遊戲",
	"MENU_BACK":          "← 返回",
	"SETTINGS_LANGUAGE":  "語言",
	"SETTINGS_TITLE":     "設定",
}

const _EN : Dictionary = {
	# Seasons
	"SEASON_SPRING":      "Spring",
	"SEASON_SUMMER":      "Summer",
	"SEASON_FALL":        "Fall",
	"SEASON_WINTER":      "Winter",
	# HUD
	"HUD_DATE":           "%s Day %d",
	"HUD_GOLD":           "G %d",
	# Tools
	"TOOL_HOE":           "Hoe",
	"TOOL_WATERING_CAN":  "Can",
	"TOOL_SEEDS":         "Seeds",
	# Time of day
	"PERIOD_MIDNIGHT":    "Midnight",
	"PERIOD_MORNING":     "Morning",
	"PERIOD_FORENOON":    "Forenoon",
	"PERIOD_AFTERNOON":   "Afternoon",
	"PERIOD_EVENING":     "Evening",
	"PERIOD_NIGHT":       "Night",
	# Game menu
	"MENU_RESUME":        "Resume",
	"MENU_SETTINGS":      "Settings",
	"MENU_QUIT":          "Quit Game",
	"MENU_BACK":          "< Back",
	"SETTINGS_LANGUAGE":  "Language",
	"SETTINGS_TITLE":     "Settings",
}


func _ready() -> void:
	_register_translation("zh_TW", _ZH_TW)
	_register_translation("en",    _EN)
	set_locale(_resolve_startup_locale())


# ── 公開 API ─────────────────────────────────────────────────────────────

func set_locale(locale: String) -> void:
	if not LOCALES.has(locale):
		return
	current_locale = locale
	TranslationServer.set_locale(locale)
	_save_locale(locale)
	locale_changed.emit(locale)


# ── 私有 ─────────────────────────────────────────────────────────────────

## 啟動時決定語言：已儲存 > 系統語言 > 英文
func _resolve_startup_locale() -> String:
	var saved : String = _load_saved_locale()
	if saved != "":
		return saved
	return _detect_system_locale()


## 將系統 locale（如 zh_TW, en_US）對應到支援的語言
func _detect_system_locale() -> String:
	var sys : String = OS.get_locale()          # e.g. "zh_TW", "zh_CN", "en_US"
	if LOCALES.has(sys):
		return sys
	var lang : String = OS.get_locale_language() # e.g. "zh", "en"
	if lang == "zh":
		return "zh_TW"
	return "en"


func _load_saved_locale() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return ""
	return cfg.get_value(CFG_SEC, CFG_KEY, "")


func _save_locale(locale: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)   # 保留其他設定（若有）
	cfg.set_value(CFG_SEC, CFG_KEY, locale)
	cfg.save(SAVE_PATH)


func _register_translation(locale: String, table: Dictionary) -> void:
	var t := Translation.new()
	t.locale = locale
	for key : String in table.keys():
		t.add_message(key, table[key])
	TranslationServer.add_translation(t)
