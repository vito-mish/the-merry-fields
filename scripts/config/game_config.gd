## GameConfig — 遊戲可調參數集中管理
## 修改這裡就能調整遊戲平衡，不需要到各個腳本翻找
extends Node

# ── 時間 ─────────────────────────────────────────────────────────────────
## 真實 1 秒 = 幾遊戲分鐘（調大 → 時間流得更快）
const TIME_SPEED: float = 1.1 # 22 遊戲小時 ≈ 真實 20 分鐘
## 每天起床時間
const DAY_START_HOUR: int = 6
## 每季天數
const DAYS_PER_SEASON: int = 28

# ── 玩家 ─────────────────────────────────────────────────────────────────
## 移動速度（像素/秒）
const PLAYER_SPEED: float = 80.0
## 體力上限
const STAMINA_MAX: float = 100.0
## 各工具體力消耗
const TOOL_STAMINA: Dictionary = {
	"hoe": 4.0,
	"watering_can": 2.0,
	"seeds": 1.0,
	"fertilizer": 3.0,
}

# ── 懲罰 ─────────────────────────────────────────────────────────────────
## 依睡覺時間決定隔天起床的體力扣除比例
## key = 幾點之後睡覺，value = 扣除比例（0.0 = 不扣，0.5 = 扣 50%）
const SLEEP_PENALTY_BY_HOUR: Dictionary = {
	1: 0.00, # 01:xx 睡：不扣
	2: 0.15, # 02:xx 睡：扣 15%
	3: 0.30, # 03:xx 睡：扣 30%
}
## 04:00 強制暈倒（送醫）：扣 50%
const FAINT_STAMINA_PENALTY: float = 0.50
## 04:00 暈倒送醫費用（G）
const DOCTOR_FEE: int = 500
