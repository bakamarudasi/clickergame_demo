class_name ItemCardFactory
extends RefCounted

# Shop タブの商品カードを構築・更新するファクトリ。
# 各カードは「棚に置かれた紙ラベル＋赤い値札」風で、上部に名前、右端に値札、
# 下に説明・信頼度ゲート・数量セレクタ・購入ボタンが並ぶ。
# 状態はすべて refresh() に集約し、build() は構造だけを組み立てる。
#
# シグナル：購入は ShopTab に転送する。

signal buy_requested(id: StringName, qty: int)

const PRICE_TAG := preload("res://assets/ui/shop_price_tag.svg")

# カード（商品ラベル紙）のトーン。雑貨店の値札紙イメージ。
const CARD_PAPER_BG := Color(0.95, 0.89, 0.74, 1.0)
const CARD_PAPER_BG_LOCKED := Color(0.74, 0.70, 0.60, 1.0)
const CARD_PAPER_BG_OWNED := Color(0.78, 0.86, 0.76, 1.0)
const CARD_BORDER_COLOR := Color(0.45, 0.32, 0.18, 0.75)
const CARD_SHADOW_COLOR := Color(0, 0, 0, 0.55)
const CARD_SHADOW_OFFSET := Vector2(2, 5)
const CARD_INK_COLOR := Color(0.18, 0.12, 0.08, 1.0)
const CARD_INK_SUB_COLOR := Color(0.32, 0.24, 0.16, 0.90)
const CARD_INK_GATE_COLOR := Color(0.70, 0.30, 0.10, 1.0)
const PRICE_TAG_SIZE := Vector2(108, 60)
const PRICE_TAG_FONT_COLOR := Color(1.0, 0.97, 0.88, 1.0)
# 通貨では「¥」を使わない方が短くて読みやすい。値札はとにかく金額の見やすさ優先。
const PRICE_TAG_FONT_SIZE := 22

var _host: Control


func _init(host: Control) -> void:
	_host = host


# 1 枚分のカードを組み立てる。返した PanelContainer は親に add_child するだけ。
func build(it: ItemData) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("item_id", it.id)

	var sbox := _make_paper_stylebox()
	panel.add_theme_stylebox_override("panel", sbox)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(vb)

	# 上段：商品名（左、伸縮）＋ 値札（右、固定）
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_child(header)

	var name_label := Label.new()
	name_label.text = _t(it.display_name)
	name_label.theme_type_variation = UIConstants.VAR_TITLE_LABEL
	name_label.add_theme_color_override("font_color", CARD_INK_COLOR)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_child(name_label)

	var price_tag := _make_price_tag(it.price)
	header.add_child(price_tag)
	var price_label: Label = price_tag.get_node("PriceLabel")

	# 説明文
	var desc_label := Label.new()
	desc_label.text = _t(it.description)
	desc_label.theme_type_variation = UIConstants.VAR_SUBTITLE_LABEL
	desc_label.add_theme_color_override("font_color", CARD_INK_SUB_COLOR)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_child(desc_label)

	# 信頼度ゲート（必要時のみ visible）
	var gate_label := Label.new()
	gate_label.theme_type_variation = UIConstants.VAR_SUBTITLE_LABEL
	gate_label.add_theme_color_override("font_color", CARD_INK_GATE_COLOR)
	gate_label.mouse_filter = Control.MOUSE_FILTER_PASS
	gate_label.visible = false
	vb.add_child(gate_label)

	# 数量セレクタ（消耗品のみ visible）
	var qty_row := HBoxContainer.new()
	qty_row.add_theme_constant_override("separation", 4)
	qty_row.alignment = BoxContainer.ALIGNMENT_CENTER
	qty_row.mouse_filter = Control.MOUSE_FILTER_PASS
	qty_row.visible = it.is_consumable
	vb.add_child(qty_row)

	var qty_selector := QuantitySelector.new()
	if it.is_consumable:
		qty_selector.build_into(qty_row, "SHOP_QTY_MAX", Vector2(52, 28), CARD_INK_COLOR)
		qty_selector.mode_changed.connect(_on_qty_changed.bind(panel))

	# 購入ボタン
	var buy_button := Button.new()
	buy_button.text = _t("SHOP_BUY_BUTTON")
	buy_button.custom_minimum_size = Vector2(0, 36)
	buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_button.add_theme_color_override("font_color", CARD_INK_COLOR)
	buy_button.pressed.connect(_on_buy_pressed.bind(panel))
	vb.add_child(buy_button)

	panel.set_meta("name_label", name_label)
	panel.set_meta("desc_label", desc_label)
	panel.set_meta("price_label", price_label)
	panel.set_meta("gate_label", gate_label)
	panel.set_meta("qty_selector", qty_selector)
	panel.set_meta("buy_button", buy_button)
	panel.set_meta("stylebox", sbox)
	return panel


# 通貨や購入状態の変化に応じて、値札・購入ボタン・紙の色を更新する。
func refresh(card: PanelContainer, it: ItemData) -> void:
	var buy_button: Button = card.get_meta("buy_button")
	var price_label: Label = card.get_meta("price_label")
	var gate_label: Label = card.get_meta("gate_label")
	var qty_selector: QuantitySelector = card.get_meta("qty_selector")
	var sbox: StyleBoxFlat = card.get_meta("stylebox")

	# 信頼度ゲート文言（あれば常に見せておく。実際の使用時ゲートは Service が判定）
	if it.trust_gate_min > 0:
		gate_label.visible = true
		gate_label.text = _t("SHOP_DETAIL_GATE_FMT") % it.trust_gate_min
	else:
		gate_label.visible = false

	# 非消耗品：すでに永続効果適用済みなら「所持済」表記＆ボタン無効
	var already_owned := not it.is_consumable and _is_permanent_effect_applied(it)
	if already_owned:
		buy_button.disabled = true
		buy_button.text = _t("SHOP_BUY_BUTTON_OWNED")
		price_label.text = _t("SHOP_PRICE_OWNED")
		sbox.bg_color = CARD_PAPER_BG_OWNED
		return

	var qty := _resolve_qty(it, qty_selector)
	var total_cost := it.price * qty
	var can_buy := qty > 0 and ShopService.can_buy(it.id, qty)

	price_label.text = _t("SHOP_PRICE_TAG_FMT") % FormatUtils.short(it.price)
	buy_button.disabled = not can_buy

	if it.is_consumable and qty > 1:
		buy_button.text = _t("SHOP_BUY_BUTTON_QTY_FMT") % [qty, FormatUtils.short(total_cost)]
	else:
		buy_button.text = _t("SHOP_BUY_BUTTON")

	if can_buy:
		sbox.bg_color = CARD_PAPER_BG
	else:
		sbox.bg_color = CARD_PAPER_BG_LOCKED


# 名前・説明・ボタン静的テキストの翻訳を更新する（NOTIFICATION_TRANSLATION_CHANGED 用）。
func rebuild_static_text(card: PanelContainer, it: ItemData) -> void:
	(card.get_meta("name_label") as Label).text = _t(it.display_name)
	(card.get_meta("desc_label") as Label).text = _t(it.description)


# 購入成功時にカード全体を弾ませて、明るくフラッシュさせる。
# アニメーションは host の create_tween 経由で生成（RefCounted は自前で Tween を作れない）。
func play_purchase_feedback(card: PanelContainer, _it: ItemData) -> void:
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2.ONE
	var tw := _host.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2(1.06, 0.94), 0.08)
	tw.tween_property(card, "scale", Vector2.ONE, 0.18)
	var flash := _host.create_tween()
	flash.tween_property(card, "modulate", Color(1.25, 1.20, 1.0, 1.0), 0.08)
	flash.tween_property(card, "modulate", Color(1, 1, 1, 1), 0.32)


# --- 内部ビルダー -------------------------------------------------------

func _make_paper_stylebox() -> StyleBoxFlat:
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = CARD_PAPER_BG
	sbox.border_color = CARD_BORDER_COLOR
	sbox.set_border_width_all(1)
	sbox.set_corner_radius_all(4)
	sbox.content_margin_left = 14
	sbox.content_margin_right = 14
	sbox.content_margin_top = 12
	sbox.content_margin_bottom = 12
	sbox.shadow_color = CARD_SHADOW_COLOR
	sbox.shadow_size = 5
	sbox.shadow_offset = CARD_SHADOW_OFFSET
	return sbox


# 価格表示用の赤い値札。背景に PRICE_TAG テクスチャを敷き、上に金額ラベルを乗せる。
func _make_price_tag(price: int) -> Control:
	var tag := Control.new()
	tag.custom_minimum_size = PRICE_TAG_SIZE
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := TextureRect.new()
	bg.name = "TagBG"
	bg.texture = PRICE_TAG
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	tag.add_child(bg)

	var label := Label.new()
	label.name = "PriceLabel"
	label.text = _t("SHOP_PRICE_TAG_FMT") % FormatUtils.short(price)
	label.add_theme_color_override("font_color", PRICE_TAG_FONT_COLOR)
	label.add_theme_font_size_override("font_size", PRICE_TAG_FONT_SIZE)
	label.add_theme_color_override("font_shadow_color", Color(0.2, 0.05, 0.02, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(label)
	# 値札テクスチャの「紐穴」分（左端の三角形）はテキスト領域から避ける。
	# anchors_preset を先に当ててから offsets を上書きする（preset がリセットするため）。
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 14
	return tag


# 数量モード → 実際の購入数。Max のときは所持金上限を引く。
func _resolve_qty(it: ItemData, qty_selector: QuantitySelector) -> int:
	if not it.is_consumable:
		return 1
	return qty_selector.resolve_qty(func() -> int: return ShopService.max_affordable(it.id))


# 既に永続効果が適用済みかを判定する。OPERATOR_UNLOCK / COSTUME_UNLOCK / RULE_ACTIVATE /
# SCOPE_GRANT は GameState 側で重複付与しても害は無いが、ボタン無効化で
# 「もう買えない」を明示する方が UX として親切。
func _is_permanent_effect_applied(it: ItemData) -> bool:
	if it.effects.is_empty():
		return false
	for eff: ItemEffect in it.effects:
		match eff.kind:
			Enums.EffectKind.OPERATOR_UNLOCK:
				if not GameState.is_operator_unlocked(eff.target_id):
					return false
			Enums.EffectKind.COSTUME_UNLOCK:
				var c := DataRegistry.get_costume(eff.target_id)
				if c == null:
					return false
				var rt := GameState.get_runtime(c.operator_id)
				if rt == null or not (c.id in rt.unlocked_costumes):
					return false
			Enums.EffectKind.RULE_ACTIVATE:
				if not GameState.has_rule(eff.target_id):
					return false
			Enums.EffectKind.SCOPE_GRANT:
				if not (eff.target_id in GameState.owned_scopes):
					return false
			_:
				# 補充系（SCOPE_BATTERY_REFILL 等）は何度でも買えるので所持判定対象外
				return false
	return true


# RefCounted には tr() が無いので TranslationServer 経由で翻訳する。
func _t(key: String) -> String:
	return TranslationServer.translate(key)


# --- 子→上位への転送 ---------------------------------------------------

func _on_buy_pressed(card: PanelContainer) -> void:
	var id: StringName = card.get_meta("item_id")
	var it := DataRegistry.get_item(id)
	if it == null:
		return
	var qty_selector: QuantitySelector = card.get_meta("qty_selector")
	var qty := _resolve_qty(it, qty_selector)
	if qty <= 0:
		return
	buy_requested.emit(id, qty)


func _on_qty_changed(_mode: int, card: PanelContainer) -> void:
	var id: StringName = card.get_meta("item_id")
	var it := DataRegistry.get_item(id)
	if it != null:
		refresh(card, it)
