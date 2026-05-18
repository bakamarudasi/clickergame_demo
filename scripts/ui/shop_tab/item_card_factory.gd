class_name ItemCardFactory
extends RefCounted

# Shop タブの商品カードを構築・更新するファクトリ。
# 「ダーク基調＋カテゴリ色アクセント＋シアン値札」のサイバー寄り意匠。

signal buy_requested(id: StringName, qty: int)

# カテゴリ別アクセント色（カードの左バー／アイコン tint に使用）。
const CATEGORY_ACCENTS := {
	Enums.ItemCategory.DAILY: Color(0.604, 0.647, 0.690, 1.0),
	Enums.ItemCategory.HOBBY: Color(0.416, 0.910, 0.612, 1.0),
	Enums.ItemCategory.BODY_CARE: Color(0.965, 0.700, 0.890, 1.0),
	Enums.ItemCategory.ROMANCE: Color(0.949, 0.451, 0.651, 1.0),
	Enums.ItemCategory.DIRECT_TOY: Color(0.780, 0.478, 0.910, 1.0),
	Enums.ItemCategory.DIRECT_DRUG: Color(0.700, 0.560, 0.980, 1.0),
	Enums.ItemCategory.DIRECT_BIND: Color(1.0, 0.353, 0.431, 1.0),
	Enums.ItemCategory.DIRECT_PROT: Color(0.302, 0.816, 0.882, 1.0),
	Enums.ItemCategory.COS_OUTFIT: Color(1.0, 0.784, 0.341, 1.0),
	Enums.ItemCategory.COS_PARTS: Color(1.0, 0.627, 0.251, 1.0),
	Enums.ItemCategory.INVITATION: Color(0.247, 0.663, 0.961, 1.0),
	Enums.ItemCategory.RULE: Color(0.365, 0.812, 0.969, 1.0),
	Enums.ItemCategory.SCOPE: Color(0.302, 0.816, 0.882, 1.0),
}

# カテゴリ別デフォルトアイコン。ItemData.icon が未設定なら category から引く。
const CATEGORY_ICONS := {
	Enums.ItemCategory.DAILY: preload("res://assets/items/category/cat_daily.svg"),
	Enums.ItemCategory.HOBBY: preload("res://assets/items/category/cat_hobby.svg"),
	Enums.ItemCategory.BODY_CARE: preload("res://assets/items/category/cat_body_care.svg"),
	Enums.ItemCategory.ROMANCE: preload("res://assets/items/category/cat_romance.svg"),
	Enums.ItemCategory.DIRECT_TOY: preload("res://assets/items/category/cat_direct_toy.svg"),
	Enums.ItemCategory.DIRECT_DRUG: preload("res://assets/items/category/cat_direct_drug.svg"),
	Enums.ItemCategory.DIRECT_BIND: preload("res://assets/items/category/cat_direct_bind.svg"),
	Enums.ItemCategory.DIRECT_PROT: preload("res://assets/items/category/cat_direct_prot.svg"),
	Enums.ItemCategory.COS_OUTFIT: preload("res://assets/items/category/cat_cos_outfit.svg"),
	Enums.ItemCategory.COS_PARTS: preload("res://assets/items/category/cat_cos_parts.svg"),
	Enums.ItemCategory.INVITATION: preload("res://assets/items/category/cat_invitation.svg"),
	Enums.ItemCategory.RULE: preload("res://assets/items/category/cat_rule.svg"),
	Enums.ItemCategory.SCOPE: preload("res://assets/items/category/cat_scope.svg"),
}
const CARD_ICON_SIZE := 78
const BUY_BUTTON_HEIGHT := 32
# 値札の高さ。コンパクトに収めつつ金額が読みやすいサイズ。
const PRICE_TAG_HEIGHT := 34
const PRICE_TAG_MIN_WIDTH := 0
# 縦バナーカードの最小サイズ。GridContainer のセル幅・高さの下限になる。
const CARD_MIN_WIDTH := 156
const CARD_MIN_HEIGHT := 270
# カード上部「掛け軸を吊るす」装飾バーの寸法。
const HANG_BAR_WIDTH := 48
const HANG_BAR_HEIGHT := 2

var _host: Control


func _init(host: Control) -> void:
	_host = host


func build(it: ItemData) -> PanelContainer:
	var accent: Color = CATEGORY_ACCENTS.get(it.category, UIConstants.COLOR_ACCENT_CYAN)

	# 縦バナー型カード。上から：吊り棒 → アイコン枠 → 名前 → 値札 → 数量＋購入。
	# 説明文は tooltip に逃がす。所持数バッジは右上にオーバーレイ。
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_MIN_WIDTH, CARD_MIN_HEIGHT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("item_id", it.id)
	panel.set_meta("accent_color", accent)

	var sbox := PanelStyler.card(accent)
	panel.add_theme_stylebox_override("panel", sbox)

	# PanelContainer の子は全部 fill されてしまうので、内側に「非 Container ラッパー」を
	# 1 枚噛ます。これで主フロー（VBox）とアンカー配置のバッジオーバーレイを共存させる。
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(layer)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", UIConstants.SEP_SMALL)
	vb.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(vb)

	# 「掛け軸を吊るす横棒」装飾。カテゴリアクセント色の細い水平バー。
	var hang := ColorRect.new()
	hang.color = accent
	hang.custom_minimum_size = Vector2(HANG_BAR_WIDTH, HANG_BAR_HEIGHT)
	hang.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hang.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(hang)

	# アイコン枠（暗背景＋細アクセント枠で「展示窓」感）。
	var icon_wrap := PanelContainer.new()
	icon_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_wrap.add_theme_stylebox_override("panel", _make_icon_window(accent))
	vb.add_child(icon_wrap)

	var icon_rect := TextureRect.new()
	icon_rect.texture = _resolve_icon(it)
	icon_rect.custom_minimum_size = Vector2(CARD_ICON_SIZE, CARD_ICON_SIZE)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.modulate = accent
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_wrap.add_child(icon_rect)

	# 名前（中央寄せ、auto-wrap）
	var name_label := Label.new()
	name_label.text = _t(it.display_name)
	name_label.theme_type_variation = UIConstants.VAR_SUBTITLE_LABEL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(name_label)

	# バナー形式に説明文を入れる余地がない。tooltip に逃がす。
	panel.tooltip_text = _t(it.description)

	# 信頼ゲート（必要時のみ visible、コンパクト表示）
	var gate_label := Label.new()
	gate_label.theme_type_variation = UIConstants.VAR_DIM_LABEL
	gate_label.add_theme_color_override("font_color", UIConstants.COLOR_WARN)
	gate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gate_label.visible = false
	vb.add_child(gate_label)

	# 所持数（消耗品のみ）
	var owned_label := Label.new()
	owned_label.theme_type_variation = UIConstants.VAR_DIM_LABEL
	owned_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owned_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owned_label.visible = it.is_consumable
	vb.add_child(owned_label)

	# 値札（カード幅いっぱい）
	var price_panel := _make_price_tag(it.price)
	price_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(price_panel)
	var price_label: Label = price_panel.get_node("PriceLabel")

	# 数量セレクタ（消耗品のみ）。バナー幅に合わせて小さめ。
	var qty_row := HBoxContainer.new()
	qty_row.add_theme_constant_override("separation", UIConstants.SEP_TIGHT)
	qty_row.alignment = BoxContainer.ALIGNMENT_CENTER
	qty_row.mouse_filter = Control.MOUSE_FILTER_PASS
	qty_row.visible = it.is_consumable
	vb.add_child(qty_row)

	var qty_selector := QuantitySelector.new()
	if it.is_consumable:
		qty_selector.build_into(qty_row, "SHOP_QTY_MAX", Vector2(34, 22))
		for b in qty_selector.buttons:
			b.theme_type_variation = UIConstants.VAR_PILL_BUTTON
		qty_selector.mode_changed.connect(_on_qty_changed.bind(panel))

	# 購入ボタン（カード下端、カード幅いっぱい）
	var buy_button := Button.new()
	buy_button.theme_type_variation = UIConstants.VAR_ACCENT_BUTTON
	buy_button.text = _t("SHOP_BUY_BUTTON")
	buy_button.custom_minimum_size = Vector2(0, BUY_BUTTON_HEIGHT)
	buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_button.pressed.connect(_on_buy_pressed.bind(panel))
	vb.add_child(buy_button)

	# 右上の状態バッジ（OWNED / STK ∞）。layer 直下にアンカーで貼る。
	var badge_panel := PanelContainer.new()
	badge_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge_panel.offset_left = -68.0
	badge_panel.offset_top = 6.0
	badge_panel.offset_right = -6.0
	badge_panel.offset_bottom = 26.0
	badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_panel.add_theme_stylebox_override("panel", _make_badge_stylebox(accent))
	badge_panel.visible = false
	layer.add_child(badge_panel)

	var badge_label := Label.new()
	badge_label.add_theme_font_size_override("font_size", UIConstants.FONT_SMALL)
	badge_label.add_theme_color_override("font_color", accent)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_panel.add_child(badge_label)

	panel.set_meta("name_label", name_label)
	panel.set_meta("price_label", price_label)
	panel.set_meta("gate_label", gate_label)
	panel.set_meta("owned_label", owned_label)
	panel.set_meta("qty_selector", qty_selector)
	panel.set_meta("buy_button", buy_button)
	panel.set_meta("stylebox", sbox)
	panel.set_meta("badge_panel", badge_panel)
	panel.set_meta("badge_label", badge_label)
	return panel


# 通貨や購入状態の変化に応じて、値札・購入ボタン・パネル色・所持数を更新する。
func refresh(card: PanelContainer, it: ItemData) -> void:
	var buy_button: Button = card.get_meta("buy_button")
	var price_label: Label = card.get_meta("price_label")
	var gate_label: Label = card.get_meta("gate_label")
	var owned_label: Label = card.get_meta("owned_label")
	var qty_selector: QuantitySelector = card.get_meta("qty_selector")
	var sbox: StyleBoxFlat = card.get_meta("stylebox")
	var badge_panel: PanelContainer = card.get_meta("badge_panel")
	var badge_label: Label = card.get_meta("badge_label")

	if it.trust_gate_min > 0:
		gate_label.visible = true
		gate_label.text = _t("SHOP_DETAIL_GATE_FMT") % it.trust_gate_min
	else:
		gate_label.visible = false

	if it.is_consumable:
		owned_label.visible = true
		owned_label.text = _t("SHOP_OWNED_COUNT_FMT") % GameState.item_count(it.id)
		# 消耗品は補充可能なので「STK ∞」バッジ。
		badge_panel.visible = true
		badge_label.text = _t("SHOP_BADGE_STOCK_INFINITE")
	else:
		owned_label.visible = false
		badge_panel.visible = false

	var already_owned := not it.is_consumable and _is_permanent_effect_applied(it)
	if already_owned:
		buy_button.disabled = true
		buy_button.text = _t("SHOP_BUY_BUTTON_OWNED")
		price_label.text = _t("SHOP_PRICE_OWNED")
		sbox.bg_color = UIConstants.RARITY_PANEL_BG_MAXED
		# 既取得アイテムは右上に「OWNED」バッジで識別。
		badge_panel.visible = true
		badge_label.text = _t("SHOP_BADGE_OWNED")
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
		sbox.bg_color = UIConstants.RARITY_PANEL_BG
	else:
		sbox.bg_color = UIConstants.RARITY_PANEL_BG_DISABLED


func rebuild_static_text(card: PanelContainer, it: ItemData) -> void:
	(card.get_meta("name_label") as Label).text = _t(it.display_name)
	card.tooltip_text = _t(it.description)


# 購入成功時にカード全体を弾ませて、シアン寄りにフラッシュさせる。
func play_purchase_feedback(card: PanelContainer, _it: ItemData) -> void:
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2.ONE
	var tw := _host.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2(1.04, 0.96), 0.08)
	tw.tween_property(card, "scale", Vector2.ONE, 0.18)
	var flash := _host.create_tween()
	flash.tween_property(card, "modulate", Color(1.20, 1.30, 1.40, 1.0), 0.08)
	flash.tween_property(card, "modulate", Color(1, 1, 1, 1), 0.32)


# --- 内部ビルダー -------------------------------------------------------

# 値札：シアンの太枠＋黒寄り背景、中央に金額。
func _make_price_tag(price: int) -> PanelContainer:
	var tag := PanelContainer.new()
	tag.custom_minimum_size = Vector2(PRICE_TAG_MIN_WIDTH, PRICE_TAG_HEIGHT)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sbox := StyleBoxFlat.new()
	sbox.bg_color = UIConstants.COLOR_BG_PANEL_DEEP
	sbox.border_color = UIConstants.COLOR_ACCENT_CYAN
	sbox.set_border_width_all(UIConstants.HAIRLINE)
	sbox.set_corner_radius_all(UIConstants.PANEL_CORNER_RADIUS)
	sbox.content_margin_left = UIConstants.SEP_MEDIUM
	sbox.content_margin_right = UIConstants.SEP_MEDIUM
	sbox.content_margin_top = UIConstants.SEP_TIGHT
	sbox.content_margin_bottom = UIConstants.SEP_TIGHT
	tag.add_theme_stylebox_override("panel", sbox)

	var label := Label.new()
	label.name = "PriceLabel"
	label.text = _t("SHOP_PRICE_TAG_FMT") % FormatUtils.short(price)
	label.theme_type_variation = UIConstants.VAR_NUMERIC_LABEL
	label.add_theme_color_override("font_color", UIConstants.COLOR_ACCENT_CYAN)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(label)
	return tag


# アイコン枠（展示窓風）。深い背景＋カテゴリアクセント枠。
func _make_icon_window(accent: Color) -> StyleBoxFlat:
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = UIConstants.COLOR_BG_PANEL_DEEP
	sbox.border_color = accent
	sbox.set_border_width_all(UIConstants.HAIRLINE)
	sbox.set_corner_radius_all(UIConstants.PANEL_CORNER_RADIUS)
	sbox.content_margin_left = 6
	sbox.content_margin_right = 6
	sbox.content_margin_top = 6
	sbox.content_margin_bottom = 6
	return sbox


# 右上バッジの StyleBox。極端に小さい角丸＋カテゴリ色の細枠。
func _make_badge_stylebox(accent: Color) -> StyleBoxFlat:
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = UIConstants.COLOR_BG_PANEL_DEEP
	sbox.border_color = accent
	sbox.set_border_width_all(UIConstants.HAIRLINE)
	sbox.set_corner_radius_all(2)
	sbox.content_margin_left = 6
	sbox.content_margin_right = 6
	sbox.content_margin_top = 2
	sbox.content_margin_bottom = 2
	return sbox


func _resolve_icon(it: ItemData) -> Texture2D:
	if it.icon != null:
		return it.icon
	return CATEGORY_ICONS.get(it.category, null)


func _resolve_qty(it: ItemData, qty_selector: QuantitySelector) -> int:
	if not it.is_consumable:
		return 1
	return qty_selector.resolve_qty(func() -> int: return ShopService.max_affordable(it.id))


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
				return false
	return true


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
