extends Control

# L字レイアウトの「枠」だけを管理する。タブの中身には触れない（疎結合）。
# タブの切替も、現在ロード中のタブの可視状態だけ操作する。

const TAB_WORK := &"work"
const TAB_ROOM := &"room"
const TAB_SHOP := &"shop"
const TAB_META := &"meta"

@onready var currency_label: Label = %CurrencyLabel
@onready var prestige_label: Label = %PrestigeLabel
@onready var per_sec_label: Label = %PerSecLabel
@onready var click_power_label: Label = %ClickPowerLabel

@onready var tab_work_button: Button = %TabWork
@onready var tab_room_button: Button = %TabRoom
@onready var tab_shop_button: Button = %TabShop
@onready var tab_meta_button: Button = %TabMeta

@onready var tab_holder: Control = %TabHolder
@onready var work_tab: Control = %WorkTab
@onready var room_tab: Control = %RoomTab
@onready var shop_tab: Control = %ShopTab
@onready var meta_tab: Control = %MetaTab

@onready var auto_timer: Timer = %AutoTimer
@onready var toast_panel: PanelContainer = %ToastPanel
@onready var toast_label: Label = %ToastLabel
@onready var toast_meta_label: Label = %ToastMetaLabel
@onready var background: ColorRect = $Background
@onready var cg_viewer: Control = %CGViewer

var _toast_tween: Tween
var _currency_count_tween: Tween
var _currency_flash_tween: Tween
# 表示中の通貨値（実値とは別に持って、lerp で実値へ追いつかせる）
var _currency_display: float = 0.0
const CURRENCY_TWEEN_SEC := 0.25
const CURRENCY_FLASH_COLOR := Color(0.55, 1.10, 0.55, 1.0)
const CURRENCY_FLASH_FADE_SEC := 0.35


func _ready() -> void:
	theme = ThemeFactory.build_default()
	background.color = UIConstants.COLOR_BG

	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.per_second_changed.connect(_on_per_second_changed)
	EventBus.click_power_changed.connect(_on_click_power_changed)
	EventBus.prestige_currency_changed.connect(_on_prestige_currency_changed)
	EventBus.toast_requested.connect(_show_toast)
	EventBus.cg_unlocked.connect(_on_cg_unlocked)
	EventBus.cg_play_requested.connect(_on_cg_play_requested)

	tab_work_button.pressed.connect(_switch_to.bind(TAB_WORK))
	tab_room_button.pressed.connect(_switch_to.bind(TAB_ROOM))
	tab_shop_button.pressed.connect(_switch_to.bind(TAB_SHOP))
	tab_meta_button.pressed.connect(_switch_to.bind(TAB_META))

	auto_timer.timeout.connect(_on_auto_tick)

	_currency_display = float(GameState.currency)
	_refresh_status_bar()
	_refresh_meta_tab_visibility()
	_switch_to(TAB_WORK)


func _refresh_meta_tab_visibility() -> void:
	# 累計¥1M に一度到達してれば永続表示。
	var unlocked := GameState.is_prestige_unlocked()
	tab_meta_button.visible = unlocked
	if not unlocked and meta_tab.visible:
		# 解放前にメタタブを開かれていたら Work に戻す（基本起こらないがガード）
		_switch_to(TAB_WORK)


func _switch_to(tab_id: StringName) -> void:
	work_tab.visible = (tab_id == TAB_WORK)
	room_tab.visible = (tab_id == TAB_ROOM)
	shop_tab.visible = (tab_id == TAB_SHOP)
	meta_tab.visible = (tab_id == TAB_META)
	tab_work_button.button_pressed = (tab_id == TAB_WORK)
	tab_room_button.button_pressed = (tab_id == TAB_ROOM)
	tab_shop_button.button_pressed = (tab_id == TAB_SHOP)
	tab_meta_button.button_pressed = (tab_id == TAB_META)


func _refresh_status_bar() -> void:
	# 通貨ラベルは _currency_display を経由してカウントアップさせる。
	# 直接 GameState.currency を書かないことで「数字がぱっと跳ねる」表示を回避。
	# 単位（¥/SEC、CLK 等）はテレメトリタイルの caption に切り出してるので
	# 各 *_label には数値だけを書き込む（FormatUtils.short で短縮表記）。
	currency_label.text = tr("UI_CURRENCY_FMT") % FormatUtils.short(int(round(_currency_display)))
	prestige_label.text = FormatUtils.short(GameState.prestige_currency)
	per_sec_label.text = FormatUtils.short(GameState.effective_per_second())
	click_power_label.text = "+" + FormatUtils.short(GameState.effective_click_power())


func _on_currency_changed(_v: int) -> void:
	_animate_currency_to(GameState.currency)
	# 累計¥1M を初回越えしたタイミングでメタタブが解放される。
	# 一度出した後は条件チェックしても変わらないのでこのまま回しっぱなしでOK。
	if not tab_meta_button.visible:
		_refresh_meta_tab_visibility()


# _currency_display を新しい値へなめらかに引き寄せる。
# tween の値変化フックで毎フレーム再描画して数字がカチャカチャ動いて見せる。
func _animate_currency_to(new_value: int) -> void:
	if _currency_count_tween != null and _currency_count_tween.is_valid():
		_currency_count_tween.kill()
	var from := _currency_display
	var to := float(new_value)
	_currency_count_tween = create_tween()
	_currency_count_tween.tween_method(_set_currency_display, from, to, CURRENCY_TWEEN_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 増加時のみ緑にフラッシュ（消費 = 通貨減少 では出さない）
	if to > from:
		_flash_currency_label()


func _set_currency_display(v: float) -> void:
	_currency_display = v
	currency_label.text = tr("UI_CURRENCY_FMT") % FormatUtils.short(int(round(_currency_display)))


func _flash_currency_label() -> void:
	if _currency_flash_tween != null and _currency_flash_tween.is_valid():
		_currency_flash_tween.kill()
	currency_label.modulate = CURRENCY_FLASH_COLOR
	_currency_flash_tween = create_tween()
	_currency_flash_tween.tween_property(currency_label, "modulate", Color(1, 1, 1, 1), CURRENCY_FLASH_FADE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_per_second_changed(_v: int) -> void:
	_refresh_status_bar()

func _on_click_power_changed(_v: int) -> void:
	_refresh_status_bar()

func _on_prestige_currency_changed(_v: int) -> void:
	_refresh_status_bar()


func _on_auto_tick() -> void:
	EconomyService.tick(1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_status_bar()


# 観測通知風トースト。本文の頭にある絵文字（⚠/✦/💀）からカテゴリを推測し、
# 左側のアクセントバー色とメタ行（[NOTICE TC] CATEGORY）を切り替える。
# EventBus.toast_requested(text) の API はそのまま維持する。
const _TOAST_KIND_INFO := 0
const _TOAST_KIND_WARN := 1
const _TOAST_KIND_ALERT := 2


func _show_toast(text: String) -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()

	var kind := _classify_toast(text)
	_apply_toast_kind(kind)
	toast_label.text = text
	toast_meta_label.text = "[%s %s]  %s" % [
		tr(_toast_kind_label_key(kind)),
		_now_tc(),
		tr(_toast_kind_category_key(kind)),
	]

	# パネルごとフェードさせて BG も一緒に消す（modulate は子に伝播する）
	toast_panel.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(UIConstants.TOAST_HOLD_SEC)
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, UIConstants.TOAST_FADE_SEC)


func _classify_toast(text: String) -> int:
	# 本文先頭の絵文字で雑にカテゴリ判定。将来 EventBus 側に kind を持たせるなら
	# 引数で受け取るように差し替える。
	if text.begins_with("⚠") or text.begins_with("⛔") or text.begins_with("💀"):
		return _TOAST_KIND_ALERT
	if text.begins_with("✦") or text.begins_with("✧"):
		return _TOAST_KIND_INFO
	if text.begins_with("⏱") or text.begins_with("🔋"):
		return _TOAST_KIND_WARN
	return _TOAST_KIND_INFO


func _apply_toast_kind(kind: int) -> void:
	var accent: Color = UIConstants.COLOR_ACCENT_CYAN
	match kind:
		_TOAST_KIND_WARN:
			accent = UIConstants.COLOR_WARN
		_TOAST_KIND_ALERT:
			accent = UIConstants.COLOR_DANGER
	# 既存の stylebox 上書き：左 4px アクセントバーをカテゴリ色に。
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.043, 0.067, 0.094, 0.95)
	sbox.border_color = accent
	sbox.border_width_left = UIConstants.ACCENT_STRIPE_WIDTH
	sbox.set_corner_radius_all(4)
	sbox.content_margin_left = 16
	sbox.content_margin_right = 20
	sbox.content_margin_top = 8
	sbox.content_margin_bottom = 8
	toast_panel.add_theme_stylebox_override("panel", sbox)
	toast_meta_label.add_theme_color_override("font_color", accent)


func _toast_kind_label_key(kind: int) -> String:
	match kind:
		_TOAST_KIND_WARN: return "UI_TOAST_KIND_WARN"
		_TOAST_KIND_ALERT: return "UI_TOAST_KIND_ALERT"
		_: return "UI_TOAST_KIND_NOTICE"


func _toast_kind_category_key(kind: int) -> String:
	match kind:
		_TOAST_KIND_WARN: return "UI_TOAST_CAT_ANOMALY"
		_TOAST_KIND_ALERT: return "UI_TOAST_CAT_ALERT"
		_: return "UI_TOAST_CAT_NOTICE"


func _now_tc() -> String:
	var t := Time.get_time_dict_from_system()
	return "TC %02d:%02d:%02d" % [int(t.hour), int(t.minute), int(t.second)]


# CG が解放された瞬間に CGViewer をフルスクリーンで開く。
# 同じ CG を二重に開かないようガード。ギャラリー再生導線は今後別タブで用意する想定。
func _on_cg_unlocked(cg_id: StringName) -> void:
	if cg_viewer.visible:
		return
	var cg := DataRegistry.get_cg(cg_id)
	if cg == null:
		return
	cg_viewer.play(cg)


# CG_PLAY エフェクト用。解放履歴は触らずに同じビューアを開く。
# 会話中の差し込み演出（既見でも毎回流したいシーン）に使う。
func _on_cg_play_requested(cg_id: StringName) -> void:
	if cg_viewer.visible:
		return
	var cg := DataRegistry.get_cg(cg_id)
	if cg == null:
		return
	cg_viewer.play(cg)
