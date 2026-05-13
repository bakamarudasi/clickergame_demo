class_name UpgradeCardFactory
extends RefCounted

# Work タブの強化カード（コルクボードの書類）を構築・更新するファクトリ。
# UI ノードの生成・スタイリング・差分更新の責務を一手に引き受け、
# WorkTab 本体はカードを並べてイベントを束ねるだけになる。
#
# シグナル：カードからの操作はすべてここで受け取り、上位（WorkTab）へ転送する。

signal expand_requested(id: StringName)
signal buy_requested(id: StringName)
signal qty_mode_changed(mode: int)

const ICON_CLICK := preload("res://assets/ui/icon_click.svg")
const ICON_AUTO := preload("res://assets/ui/icon_auto.svg")
const ICON_MULT := preload("res://assets/ui/icon_mult.svg")
const PUSHPIN := preload("res://assets/ui/pushpin.svg")

# 強化カードを「コルクボードに留めた書類」風に表示するためのトーン。
const CARD_PAPER_BG := Color(0.96, 0.93, 0.84, 1.0)
const CARD_PAPER_BG_DISABLED := Color(0.78, 0.74, 0.66, 1.0)
const CARD_PAPER_BG_MAXED := Color(0.70, 0.78, 0.68, 1.0)
const CARD_INK_COLOR := Color(0.18, 0.14, 0.10, 1.0)
const CARD_INK_SUB_COLOR := Color(0.28, 0.22, 0.16, 0.85)
const CARD_PIN_SIZE := 26
const CARD_ICON_SIZE := 28
const ICON_TINT_ON_PAPER := Color(0.32, 0.26, 0.20, 1.0)
const CARD_BORDER_COLOR := Color(0.45, 0.35, 0.22, 0.55)   # 紙のフチ（控えめ）
const CARD_SHADOW_COLOR := Color(0, 0, 0, 0.45)            # 紙の落ち影
const CARD_SHADOW_OFFSET := Vector2(2, 4)
const RARITY_RIBBON_HEIGHT := 4                             # レア度カラーリボンの太さ
# レア度色を「紙の上の文字色」として使う際の暗さ補正。
# .darkened(amount) は v=0 寄りに線形補完。0.55 程度で淡い色も十分に読める。
const RARITY_INK_DARKEN := 0.55

var _host: Control


func _init(host: Control) -> void:
	_host = host


# 1 枚分のカードを組み立てる。返した PanelContainer は親に add_child するだけ。
# refresh() で都度参照する子ノードはすべて set_meta で索引化する。
func build(u: UpgradeData, initial_qty_mode: int) -> PanelContainer:
	var rarity_color: Color = UIConstants.RARITY_COLORS.get(
		u.rarity, UIConstants.RARITY_COLORS[Enums.UpgradeRarity.COMMON]
	)
	var name_color := _ink_rarity_color(rarity_color)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("upgrade_id", u.id)
	panel.set_meta("rarity_color", rarity_color)

	var sbox := _make_paper_stylebox()
	panel.add_theme_stylebox_override("panel", sbox)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(vb)

	_add_pin_row(vb)
	_add_rarity_ribbon(vb, rarity_color)

	var name_label := _add_header_row(vb, u, name_color)
	var lv_label := name_label.get_meta("lv_label") as Label

	var effect_label := _add_effect_label(vb, u)
	var cost_label := _add_cost_label(vb)

	var expand := _add_expand_section(vb)
	var detail := _add_expand_detail(expand, u, name_color)
	var qty_selector := _add_qty_selector(expand, initial_qty_mode)
	var afford_label := _add_afford_label(expand)
	var buy_button := _add_buy_button(expand, u, name_color)

	# クリックでアコーディオン展開（buy_button は STOP で食う）
	panel.gui_input.connect(_on_card_gui_input.bind(u.id))

	panel.set_meta("name_label", name_label)
	panel.set_meta("lv_label", lv_label)
	panel.set_meta("effect_label", effect_label)
	panel.set_meta("cost_label", cost_label)
	panel.set_meta("desc_label", detail.desc)
	panel.set_meta("expand", expand)
	panel.set_meta("buy_button", buy_button)
	panel.set_meta("stylebox", sbox)
	panel.set_meta("rarity_badge", detail.rarity_badge)
	panel.set_meta("total_value", detail.total_value)
	panel.set_meta("invested_value", detail.invested_value)
	panel.set_meta("next_value", detail.next_value)
	panel.set_meta("afford_label", afford_label)
	panel.set_meta("qty_selector", qty_selector)
	panel.set_meta("glow_tween", null)

	return panel


# qty_resolver: id を渡すと現モードに対応する qty を返す Callable。
# WorkTab 側で「全カード共有の qty_mode」を解決する。
func refresh(card: PanelContainer, u: UpgradeData, qty_mode: int, qty_resolver: Callable) -> void:
	var lv := GameState.get_upgrade_level(u.id)
	var maxed := u.max_level > 0 and lv >= u.max_level

	var lv_label: Label = card.get_meta("lv_label")
	var cost_label: Label = card.get_meta("cost_label")
	var buy_button: Button = card.get_meta("buy_button")
	var total_value: Label = card.get_meta("total_value")
	var invested_value: Label = card.get_meta("invested_value")
	var next_value: Label = card.get_meta("next_value")
	var afford_label: Label = card.get_meta("afford_label")
	var qty_selector: QuantitySelector = card.get_meta("qty_selector")

	total_value.text = _format_total_contribution(u, lv)
	invested_value.text = _t("WORK_UPGRADE_COST_FMT") % FormatUtils.short(_cumulative_invested(u, lv))

	# 数量ボタンの押下状態を共有モードに同期（他カードからの伝搬を反映）
	qty_selector.set_mode_silent(qty_mode)

	# 数量モードに応じた購入数と合計コスト。MAX状態ならどちらも 0。
	var qty := 0
	var total_cost := 0
	if not maxed:
		qty = int(qty_resolver.call(u.id))
		total_cost = EconomyService.cumulative_cost(u.id, qty)

	var can_buy := qty > 0 and GameState.currency >= total_cost
	# 折りたたみ時のコスト表示は常に「次の1Lv分」で読みやすさを優先。
	var single_cost := EconomyService.current_cost(u.id) if not maxed else -1

	if maxed:
		lv_label.text = _t("WORK_UPGRADE_LV_MAX_FMT") % lv
		cost_label.text = _t("WORK_UPGRADE_COST_MAX")
		next_value.text = _t("WORK_UPGRADE_COST_MAX")
		afford_label.text = ""
		buy_button.disabled = true
		buy_button.text = _t("WORK_UPGRADE_BUY_BUTTON")
		qty_selector.set_enabled(false)
	else:
		lv_label.text = _t("WORK_UPGRADE_LV_FMT") % lv
		cost_label.text = _t("WORK_UPGRADE_COST_FMT") % FormatUtils.short(single_cost)
		next_value.text = _t("WORK_UPGRADE_COST_FMT") % FormatUtils.short(total_cost)
		qty_selector.set_enabled(true)
		buy_button.disabled = not can_buy
		# ×Max でも qty=1 なら "購入する"、それ以外は数量つきフォーマット。
		if qty > 1:
			buy_button.text = _t("WORK_UPGRADE_BUY_BUTTON_QTY_FMT") % [qty, FormatUtils.short(total_cost)]
		else:
			buy_button.text = _t("WORK_UPGRADE_BUY_BUTTON")
		if can_buy:
			afford_label.text = _t("WORK_UPGRADE_STATS_AFFORD")
			afford_label.add_theme_color_override("font_color",
				_ink_rarity_color(UIConstants.RARITY_COLORS[u.rarity]))
		else:
			# ×Max で qty=0（=単発も買えない）の時は 1Lv 分の不足額を出す方が親切。
			var ref_cost := total_cost if qty > 0 else single_cost
			var short_by := ref_cost - GameState.currency
			afford_label.text = _t("WORK_UPGRADE_STATS_SHORT") % FormatUtils.short(short_by)
			afford_label.add_theme_color_override("font_color", CARD_INK_SUB_COLOR)

	# 買える時だけ脈動。MAX / 買えない時は通常表示で固定。
	set_glow(card, can_buy)
	# 買えない時は紙が褪色、MAX 時はアーカイブ色（達成感）に切替
	var sbox: StyleBoxFlat = card.get_meta("stylebox")
	if maxed:
		sbox.bg_color = CARD_PAPER_BG_MAXED
	elif can_buy:
		sbox.bg_color = CARD_PAPER_BG
	else:
		sbox.bg_color = CARD_PAPER_BG_DISABLED


# 静的ラベル（名前・説明・効果文・購入ボタン）の翻訳を更新する。
# NOTIFICATION_TRANSLATION_CHANGED で呼び出す。
func rebuild_static_text(card: PanelContainer, u: UpgradeData) -> void:
	(card.get_meta("name_label") as Label).text = _t(u.display_name)
	(card.get_meta("desc_label") as Label).text = _t(u.description)
	(card.get_meta("effect_label") as Label).text = _format_effect(u)
	(card.get_meta("buy_button") as Button).text = _t("WORK_UPGRADE_BUY_BUTTON")


func set_expanded(card: PanelContainer, on: bool) -> void:
	var expand: VBoxContainer = card.get_meta("expand")
	expand.visible = on


func set_glow(card: PanelContainer, on: bool) -> void:
	var existing: Tween = card.get_meta("glow_tween")
	if existing != null and existing.is_valid():
		existing.kill()
		card.set_meta("glow_tween", null)
	if not on:
		card.modulate = Color(1, 1, 1, 1)
		return
	var tw := _host.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var half := UIConstants.CARD_GLOW_PERIOD * 0.5
	var hi := Color(UIConstants.CARD_GLOW_MAX, UIConstants.CARD_GLOW_MAX, UIConstants.CARD_GLOW_MAX, 1.0)
	var lo := Color(UIConstants.CARD_GLOW_MIN, UIConstants.CARD_GLOW_MIN, UIConstants.CARD_GLOW_MIN, 1.0)
	tw.tween_property(card, "modulate", hi, half)
	tw.tween_property(card, "modulate", lo, half)
	card.set_meta("glow_tween", tw)


# どの効果種別タブに属するかを返す。WorkTab 側で 3 つの GridContainer を出し分ける。
static func grid_index_for_effect(kind: Enums.UpgradeEffectKind) -> int:
	match kind:
		Enums.UpgradeEffectKind.ADD_PER_SEC: return 1
		Enums.UpgradeEffectKind.MULT_CLICK: return 2
		_: return 0


# --- 内部ビルダー -------------------------------------------------------

func _make_paper_stylebox() -> StyleBoxFlat:
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = CARD_PAPER_BG
	# 紙のフチは抑え気味、レア度はリボン + 文字色で示す
	sbox.border_color = CARD_BORDER_COLOR
	sbox.set_border_width_all(1)
	sbox.set_corner_radius_all(3)
	sbox.content_margin_left = 14
	sbox.content_margin_right = 14
	# 上部はピン分の余白を確保
	sbox.content_margin_top = 6
	sbox.content_margin_bottom = 12
	# 紙の影
	sbox.shadow_color = CARD_SHADOW_COLOR
	sbox.shadow_size = 6
	sbox.shadow_offset = CARD_SHADOW_OFFSET
	return sbox


func _add_pin_row(parent: VBoxContainer) -> void:
	var pin_row := CenterContainer.new()
	pin_row.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(pin_row)
	var pin := TextureRect.new()
	pin.texture = PUSHPIN
	pin.custom_minimum_size = Vector2(CARD_PIN_SIZE, CARD_PIN_SIZE)
	pin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin_row.add_child(pin)


func _add_rarity_ribbon(parent: VBoxContainer, rarity_color: Color) -> void:
	var ribbon := ColorRect.new()
	ribbon.color = rarity_color
	ribbon.custom_minimum_size = Vector2(0, RARITY_RIBBON_HEIGHT)
	ribbon.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(ribbon)


# 名前ラベルを返す（Lv ラベルは meta に格納）。
func _add_header_row(parent: VBoxContainer, u: UpgradeData, name_color: Color) -> Label:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(header)

	var icon := _make_effect_icon(u.effect_kind, CARD_ICON_SIZE)
	header.add_child(icon)

	var name_label := Label.new()
	name_label.text = _t(u.display_name)
	name_label.theme_type_variation = UIConstants.VAR_SUBTITLE_LABEL
	name_label.add_theme_color_override("font_color", name_color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_child(name_label)

	var lv_label := Label.new()
	lv_label.theme_type_variation = UIConstants.VAR_SUBTITLE_LABEL
	lv_label.add_theme_color_override("font_color", CARD_INK_COLOR)
	lv_label.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_child(lv_label)
	name_label.set_meta("lv_label", lv_label)
	return name_label


func _add_effect_label(parent: VBoxContainer, u: UpgradeData) -> Label:
	var l := Label.new()
	l.text = _format_effect(u)
	l.add_theme_color_override("font_color", CARD_INK_COLOR)
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(l)
	return l


func _add_cost_label(parent: VBoxContainer) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", CARD_INK_SUB_COLOR)
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(l)
	return l


func _add_expand_section(parent: VBoxContainer) -> VBoxContainer:
	var expand := VBoxContainer.new()
	expand.visible = false
	expand.add_theme_constant_override("separation", 8)
	expand.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(expand)
	expand.add_child(HSeparator.new())
	return expand


# 詳細領域を組み立て、refresh で参照する 4 ラベル + バッジ + 説明文を返す。
func _add_expand_detail(expand: VBoxContainer, u: UpgradeData, name_color: Color) -> Dictionary:
	# ヘッダ行：大アイコン + レア度バッジ
	var detail_head := HBoxContainer.new()
	detail_head.add_theme_constant_override("separation", 10)
	detail_head.mouse_filter = Control.MOUSE_FILTER_PASS
	expand.add_child(detail_head)

	var big_icon := _make_effect_icon(u.effect_kind, 56)
	detail_head.add_child(big_icon)

	var rarity_badge := Label.new()
	rarity_badge.text = _rarity_key(u.rarity)
	rarity_badge.theme_type_variation = UIConstants.VAR_TITLE_LABEL
	rarity_badge.add_theme_color_override("font_color", name_color)
	rarity_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rarity_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rarity_badge.mouse_filter = Control.MOUSE_FILTER_PASS
	detail_head.add_child(rarity_badge)

	# 説明文
	var desc_label := Label.new()
	desc_label.text = _t(u.description)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.theme_type_variation = UIConstants.VAR_SUBTITLE_LABEL
	desc_label.add_theme_color_override("font_color", CARD_INK_COLOR)
	desc_label.mouse_filter = Control.MOUSE_FILTER_PASS
	expand.add_child(desc_label)

	expand.add_child(HSeparator.new())

	# 統計グリッド（ラベル｜値 の2列）
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 12)
	stats.add_theme_constant_override("v_separation", 4)
	stats.mouse_filter = Control.MOUSE_FILTER_PASS
	expand.add_child(stats)

	var per_lv_value := _add_stat_row(stats, "WORK_UPGRADE_STATS_PER_LV")
	per_lv_value.text = _format_effect(u)
	var total_value := _add_stat_row(stats, "WORK_UPGRADE_STATS_TOTAL")
	var invested_value := _add_stat_row(stats, "WORK_UPGRADE_STATS_INVESTED")
	var next_value := _add_stat_row(stats, "WORK_UPGRADE_STATS_NEXT_COST")

	return {
		"rarity_badge": rarity_badge,
		"desc": desc_label,
		"total_value": total_value,
		"invested_value": invested_value,
		"next_value": next_value,
	}


# 1 行ぶんのラベル/値ペアを stats グリッドに追加し、値ラベルを返す。
func _add_stat_row(stats: GridContainer, key: String) -> Label:
	var key_label := Label.new()
	# Godot は Label.text に翻訳キーが入っていれば自動で tr する。
	# 静的キーラベルはこの仕組みでロケール切替に追従させる。
	key_label.text = key
	key_label.theme_type_variation = UIConstants.VAR_SUBTITLE_LABEL
	key_label.add_theme_color_override("font_color", CARD_INK_SUB_COLOR)
	key_label.mouse_filter = Control.MOUSE_FILTER_PASS
	stats.add_child(key_label)

	var value_label := Label.new()
	value_label.theme_type_variation = UIConstants.VAR_SUBTITLE_LABEL
	value_label.add_theme_color_override("font_color", CARD_INK_COLOR)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.mouse_filter = Control.MOUSE_FILTER_PASS
	stats.add_child(value_label)
	return value_label


# 数量セレクタ（×1 / ×10 / ×100 / ×Max）。全カードで同じモードを共有する前提。
func _add_qty_selector(expand: VBoxContainer, initial_mode: int) -> QuantitySelector:
	var qty_row := HBoxContainer.new()
	qty_row.add_theme_constant_override("separation", 4)
	qty_row.alignment = BoxContainer.ALIGNMENT_CENTER
	qty_row.mouse_filter = Control.MOUSE_FILTER_PASS
	expand.add_child(qty_row)

	var sel := QuantitySelector.new()
	sel.build_into(qty_row, "WORK_UPGRADE_QTY_MAX", Vector2(56, 28), CARD_INK_COLOR)
	sel.set_mode_silent(initial_mode)
	sel.mode_changed.connect(_on_qty_mode_changed)
	return sel


func _add_afford_label(expand: VBoxContainer) -> Label:
	var l := Label.new()
	l.theme_type_variation = UIConstants.VAR_SUBTITLE_LABEL
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", CARD_INK_COLOR)
	expand.add_child(l)
	return l


func _add_buy_button(expand: VBoxContainer, u: UpgradeData, name_color: Color) -> Button:
	var b := Button.new()
	b.text = _t("WORK_UPGRADE_BUY_BUTTON")
	b.custom_minimum_size = Vector2(0, 36)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_color_override("font_color", name_color)
	b.pressed.connect(_on_buy_pressed.bind(u.id))
	expand.add_child(b)
	return b


func _make_effect_icon(kind: Enums.UpgradeEffectKind, size: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = _icon_for_effect(kind)
	icon.custom_minimum_size = Vector2(size, size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	# アイコンは元々ダーク背景向け。紙の上では暗めにトーン調整
	icon.modulate = ICON_TINT_ON_PAPER
	return icon


# --- 純粋関数 -----------------------------------------------------------

func _ink_rarity_color(c: Color) -> Color:
	return c.darkened(RARITY_INK_DARKEN)


func _rarity_key(r: Enums.UpgradeRarity) -> String:
	match r:
		Enums.UpgradeRarity.LEGENDARY: return "WORK_UPGRADE_RARITY_LEGENDARY"
		Enums.UpgradeRarity.EPIC: return "WORK_UPGRADE_RARITY_EPIC"
		Enums.UpgradeRarity.RARE: return "WORK_UPGRADE_RARITY_RARE"
		_: return "WORK_UPGRADE_RARITY_COMMON"


func _icon_for_effect(kind: Enums.UpgradeEffectKind) -> Texture2D:
	match kind:
		Enums.UpgradeEffectKind.ADD_CLICK: return ICON_CLICK
		Enums.UpgradeEffectKind.ADD_PER_SEC: return ICON_AUTO
		Enums.UpgradeEffectKind.MULT_CLICK: return ICON_MULT
	return ICON_CLICK


func _format_effect(u: UpgradeData) -> String:
	var amt := FormatUtils.short(int(round(u.effect_amount)))
	match u.effect_kind:
		Enums.UpgradeEffectKind.ADD_CLICK:
			return _t("WORK_UPGRADE_EFFECT_CLICK") % amt
		Enums.UpgradeEffectKind.ADD_PER_SEC:
			return _t("WORK_UPGRADE_EFFECT_SEC") % amt
		Enums.UpgradeEffectKind.MULT_CLICK:
			return _t("WORK_UPGRADE_EFFECT_MULT") % ("%.1f" % u.effect_amount)
	return ""


func _format_total_contribution(u: UpgradeData, level: int) -> String:
	var amt := u.effect_amount * float(level)
	match u.effect_kind:
		Enums.UpgradeEffectKind.ADD_CLICK:
			return _t("WORK_UPGRADE_EFFECT_CLICK") % FormatUtils.short(int(round(amt)))
		Enums.UpgradeEffectKind.ADD_PER_SEC:
			return _t("WORK_UPGRADE_EFFECT_SEC") % FormatUtils.short(int(round(amt)))
		Enums.UpgradeEffectKind.MULT_CLICK:
			# 倍率は重ねがけ：effect_amount^level
			var mult := pow(u.effect_amount, level)
			return _t("WORK_UPGRADE_EFFECT_MULT") % ("%.1f" % mult)
	return ""


# 等比級数による「これまでに投資した累計コスト」を返す。
func _cumulative_invested(u: UpgradeData, level: int) -> int:
	if level <= 0:
		return 0
	var sum := 0.0
	var c := float(u.base_cost)
	for i in level:
		sum += c
		c *= u.cost_growth
	return int(sum)


# RefCounted には tr() が無いので TranslationServer 経由で翻訳する。
func _t(key: String) -> String:
	return TranslationServer.translate(key)


# --- 子→上位への転送 ---------------------------------------------------

func _on_card_gui_input(event: InputEvent, id: StringName) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			expand_requested.emit(id)


func _on_buy_pressed(id: StringName) -> void:
	buy_requested.emit(id)


func _on_qty_mode_changed(mode: int) -> void:
	qty_mode_changed.emit(mode)
