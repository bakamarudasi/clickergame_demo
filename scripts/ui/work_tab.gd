extends Control

# Workタブ。クリックでの通貨生成と強化購入のみを担当。
# 他タブを直接参照しない。EconomyService 経由でのみ状態を変える。
#
# 役割は orchestrator に絞り、実装の細部は以下に委譲：
#  - クリック演出（紙吹雪・スタンプ・+N ポップアップ）→ ClickFeedback
#  - ゴールデン書類のスポーン/取得      → GoldenDocument
#  - 強化カードの構築/差分更新           → UpgradeCardFactory
#  - 数量セレクタ（×1/×10/×100/×Max）    → QuantitySelector

@onready var document_button: TextureButton = %DocumentButton
@onready var upgrade_tabs: TabContainer = %UpgradeTabs
@onready var upgrade_grid_click: GridContainer = %UpgradeGridClick
@onready var upgrade_grid_auto: GridContainer = %UpgradeGridAuto
@onready var upgrade_grid_mult: GridContainer = %UpgradeGridMult
@onready var sticky_target_label: Label = %StickyTargetLabel
@onready var prestige_bar: PanelContainer = %PrestigeBar
@onready var prestige_preview: Label = %PrestigePreview
@onready var prestige_button: Button = %PrestigeButton
@onready var prestige_confirm: ConfirmationDialog = %PrestigeConfirm
@onready var title_panel: PanelContainer = %TitlePanel

var _click_feedback: ClickFeedback
var _golden: GoldenDocument
var _card_factory: UpgradeCardFactory

# id → カード Dict（再構築せず差分更新するための索引）
var _cards: Dictionary = {}
var _expanded_id: StringName = &""
# 数量モード（×1 / ×10 / ×100 / ×Max）。Shopタブと同じ流儀で全カード共有。
var _qty_mode: int = QuantitySelector.MODE_X1


func _ready() -> void:
	document_button.pressed.connect(_on_click_pressed)
	EventBus.currency_changed.connect(_refresh_all_cards)
	EventBus.currency_changed.connect(_refresh_prestige_bar)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.meta_upgrade_purchased.connect(_on_meta_purchased)
	prestige_button.pressed.connect(_on_prestige_button_pressed)
	prestige_confirm.confirmed.connect(_on_prestige_confirmed)

	_click_feedback = ClickFeedback.new(self, document_button)
	_golden = GoldenDocument.new(self)
	_card_factory = UpgradeCardFactory.new(self)
	_card_factory.expand_requested.connect(_toggle_expand)
	_card_factory.buy_requested.connect(_on_buy_pressed)
	_card_factory.qty_mode_changed.connect(_set_qty_mode)

	_style_title_panel()
	_apply_tab_titles()
	_build_upgrade_cards()
	_refresh_prestige_bar(0)


# TabContainer のタブ名は子ノード名 or set_tab_title。
# ロケール切替で追従させるため、translation key を tr() で展開して入れる。
func _apply_tab_titles() -> void:
	if upgrade_tabs == null:
		return
	upgrade_tabs.set_tab_title(0, tr("WORK_UPGRADE_TAB_CLICK"))
	upgrade_tabs.set_tab_title(1, tr("WORK_UPGRADE_TAB_AUTO"))
	upgrade_tabs.set_tab_title(2, tr("WORK_UPGRADE_TAB_MULT"))


# 「アップグレード」見出しを木の名札風に。コルクボード上で浮いて見えるよう影付き。
func _style_title_panel() -> void:
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.25, 0.16, 0.09, 1.0)
	sbox.border_color = Color(0.55, 0.40, 0.20, 1.0)
	sbox.set_border_width_all(1)
	sbox.set_corner_radius_all(4)
	sbox.content_margin_left = 14
	sbox.content_margin_right = 14
	sbox.content_margin_top = 6
	sbox.content_margin_bottom = 6
	sbox.shadow_color = Color(0, 0, 0, 0.45)
	sbox.shadow_size = 4
	sbox.shadow_offset = Vector2(1, 2)
	title_panel.add_theme_stylebox_override("panel", sbox)
	var title_label := title_panel.get_child(0) as Label
	if title_label != null:
		title_label.add_theme_color_override("font_color", Color(0.97, 0.91, 0.75, 1.0))


func _on_click_pressed() -> void:
	var gained := GameState.click_power
	EconomyService.click()
	_click_feedback.play(gained)


# --- カードビルド -------------------------------------------------------

func _build_upgrade_cards() -> void:
	var grids := [upgrade_grid_click, upgrade_grid_auto, upgrade_grid_mult]
	for g in grids:
		for child in g.get_children():
			child.queue_free()
	_cards.clear()
	# 効果種類タブ別に base_cost 昇順（安いやつが上）で並べる。
	var upgrades: Array = DataRegistry.upgrades.values()
	upgrades.sort_custom(func(a: UpgradeData, b: UpgradeData) -> bool:
		return a.base_cost < b.base_cost)
	for u: UpgradeData in upgrades:
		# メタ強化によるゲート：requires_meta が未解放なら表示しない
		if not GameState.has_meta_unlock(u.requires_meta):
			continue
		var card := _card_factory.build(u, _qty_mode)
		grids[UpgradeCardFactory.grid_index_for_effect(u.effect_kind)].add_child(card)
		_cards[u.id] = card
	_refresh_all_cards(0)


# --- 状態更新 -----------------------------------------------------------

func _refresh_all_cards(_v: int = 0) -> void:
	for id in _cards.keys():
		_refresh_card(id)
	_refresh_sticky_target()


func _refresh_card(id: StringName) -> void:
	var card: PanelContainer = _cards.get(id)
	if card == null:
		return
	var u := DataRegistry.get_upgrade(id)
	if u == null:
		return
	_card_factory.refresh(card, u, _qty_mode, _resolve_qty_for)


func _refresh_sticky_target() -> void:
	# 「次の目標」付箋：未MAX強化の中で最も安いものを指す。
	var min_cost := -1
	var target_id: StringName = &""
	for id in DataRegistry.upgrades:
		var u := DataRegistry.get_upgrade(id)
		if u == null:
			continue
		var lv := GameState.get_upgrade_level(id)
		if u.max_level > 0 and lv >= u.max_level:
			continue
		var c := EconomyService.current_cost(id)
		if min_cost < 0 or c < min_cost:
			min_cost = c
			target_id = id
	if target_id == &"":
		sticky_target_label.text = tr("WORK_STICKY_ALL_MAX")
		return
	var u := DataRegistry.get_upgrade(target_id)
	sticky_target_label.text = "%s\n%s\n¥ %s" % [
		tr("WORK_STICKY_HEADING"),
		tr(u.display_name),
		FormatUtils.short(min_cost),
	]


# --- インタラクション ---------------------------------------------------

func _toggle_expand(id: StringName) -> void:
	if _expanded_id == id:
		_set_expanded(id, false)
		_expanded_id = &""
		return
	if _expanded_id != &"":
		_set_expanded(_expanded_id, false)
	_set_expanded(id, true)
	_expanded_id = id


func _set_expanded(id: StringName, on: bool) -> void:
	var card: PanelContainer = _cards.get(id)
	if card == null:
		return
	_card_factory.set_expanded(card, on)


# 全カードでモードは共有なので _qty_mode から直接解決すれば足りる。
# Max のときだけ id ごとの所持金上限を引く。
func _resolve_qty_for(id: StringName) -> int:
	match _qty_mode:
		QuantitySelector.MODE_X1: return 1
		QuantitySelector.MODE_X10: return 10
		QuantitySelector.MODE_X100: return 100
		QuantitySelector.MODE_MAX: return EconomyService.max_affordable_qty(id)
		_: return 1


func _set_qty_mode(mode: int) -> void:
	if _qty_mode == mode:
		return
	_qty_mode = mode
	# 他カードのトグル状態と表示（コスト/購入可否）を一斉同期。
	_refresh_all_cards(0)


func _on_buy_pressed(id: StringName) -> void:
	var qty := _resolve_qty_for(id)
	if qty <= 0:
		return
	EconomyService.buy_upgrade_bulk(id, qty)


func _on_upgrade_purchased(id: StringName, _lv: int) -> void:
	_refresh_card(id)


func _on_meta_purchased(_id: StringName, _lv: int) -> void:
	# メタ強化購入で requires_meta 解放されたカードが増える可能性 → 再構築
	_build_upgrade_cards()


# --- プレステージ -------------------------------------------------------

func _refresh_prestige_bar(_v: int = 0) -> void:
	if not GameState.is_prestige_unlocked():
		prestige_bar.visible = false
		return
	prestige_bar.visible = true
	var gain := GameState.compute_prestige_currency_gained()
	prestige_preview.text = tr("WORK_PRESTIGE_PREVIEW_FMT") % FormatUtils.short(gain)
	prestige_button.disabled = gain <= 0


func _on_prestige_button_pressed() -> void:
	var gain := GameState.compute_prestige_currency_gained()
	var pc := GameState.prestige_count
	var lines := [
		tr("WORK_PRESTIGE_CONFIRM_BODY_LOSS"),
		tr("WORK_PRESTIGE_CONFIRM_BODY_KEEP"),
		"",
		tr("WORK_PRESTIGE_CONFIRM_BODY_GAIN") % FormatUtils.short(gain),
		tr("WORK_PRESTIGE_CONFIRM_BODY_RUN") % [pc, pc + 1],
	]
	prestige_confirm.dialog_text = "\n".join(lines)
	prestige_confirm.popup_centered()


func _on_prestige_confirmed() -> void:
	GameState.do_prestige_reset()
	# 走行リセットされたので強化カードを再構築 + プレステージバーも更新
	_build_upgrade_cards()
	_refresh_prestige_bar(0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_rebuild_static_text()


func _rebuild_static_text() -> void:
	_apply_tab_titles()
	for id in _cards.keys():
		var card: PanelContainer = _cards[id]
		var u := DataRegistry.get_upgrade(id)
		if u == null:
			continue
		_card_factory.rebuild_static_text(card, u)
	_refresh_all_cards(0)
