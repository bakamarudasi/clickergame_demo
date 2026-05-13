extends Control

# Shopタブ。雑貨店の棚をめくる感覚で商品を選んで買う。
# 他タブを直接参照しない。ShopService 経由でのみ購入処理を行う。
#
# 役割は orchestrator に絞り、カード組み立て・更新は ItemCardFactory に委譲。

@onready var title_panel: PanelContainer = %TitlePanel
@onready var category_bar: HBoxContainer = %CategoryBar
@onready var item_grid: GridContainer = %ItemGrid
@onready var empty_label: Label = %EmptyLabel

const CATEGORY_ENTRIES := [
	{ "label_key": "CATEGORY_DAILY", "value": Enums.ItemCategory.DAILY },
	{ "label_key": "CATEGORY_HOBBY", "value": Enums.ItemCategory.HOBBY },
	{ "label_key": "CATEGORY_BODY_CARE", "value": Enums.ItemCategory.BODY_CARE },
	{ "label_key": "CATEGORY_ROMANCE", "value": Enums.ItemCategory.ROMANCE },
	{ "label_key": "CATEGORY_DIRECT_TOY", "value": Enums.ItemCategory.DIRECT_TOY },
	{ "label_key": "CATEGORY_DIRECT_DRUG", "value": Enums.ItemCategory.DIRECT_DRUG },
	{ "label_key": "CATEGORY_DIRECT_BIND", "value": Enums.ItemCategory.DIRECT_BIND },
	{ "label_key": "CATEGORY_DIRECT_PROT", "value": Enums.ItemCategory.DIRECT_PROT },
	{ "label_key": "CATEGORY_COS_OUTFIT", "value": Enums.ItemCategory.COS_OUTFIT },
	{ "label_key": "CATEGORY_COS_PARTS", "value": Enums.ItemCategory.COS_PARTS },
	{ "label_key": "CATEGORY_INVITATION", "value": Enums.ItemCategory.INVITATION },
	{ "label_key": "CATEGORY_RULE", "value": Enums.ItemCategory.RULE },
	{ "label_key": "CATEGORY_SCOPE", "value": Enums.ItemCategory.SCOPE },
]

# カテゴリ見出し（木の名札風）のトーン
const CAT_BTN_BG := Color(0.42, 0.27, 0.13, 1.0)
const CAT_BTN_BG_ACTIVE := Color(0.65, 0.45, 0.22, 1.0)
const CAT_BTN_BG_HOVER := Color(0.50, 0.33, 0.16, 1.0)
const CAT_BTN_INK := Color(0.97, 0.91, 0.75, 1.0)
const CAT_BTN_INK_ACTIVE := Color(1.0, 0.97, 0.85, 1.0)
const CAT_BTN_BORDER := Color(0.30, 0.18, 0.08, 1.0)

# 「ショップ」看板（木札風）のトーン。Work タブ の見出しと揃える。
const TITLE_PANEL_BG := Color(0.25, 0.16, 0.09, 1.0)
const TITLE_PANEL_BORDER := Color(0.55, 0.40, 0.20, 1.0)
const TITLE_PANEL_FONT := Color(0.97, 0.91, 0.75, 1.0)
const TITLE_PANEL_SHADOW := Color(0, 0, 0, 0.45)

var _selected_category: int = Enums.ItemCategory.DAILY
var _card_factory: ItemCardFactory
# item_id → カード（差分更新のための索引）
var _cards: Dictionary = {}
var _category_group: ButtonGroup
# category 値 → 対応 Button（翻訳変更で再ラベルする時に使う）
var _category_buttons: Dictionary = {}


func _ready() -> void:
	_card_factory = ItemCardFactory.new(self)
	_card_factory.buy_requested.connect(_on_buy_requested)

	EventBus.currency_changed.connect(_refresh_all_cards)
	EventBus.item_purchased.connect(_on_item_purchased)
	# Room タブ等での消費で在庫が変わったら所持数表示を更新する
	EventBus.inventory_changed.connect(_on_inventory_changed)
	# メタ強化購入で requires_meta 解放されたアイテムが陳列に増える可能性 → 再構築
	EventBus.meta_upgrade_purchased.connect(_on_meta_upgrade_purchased)

	_style_title_panel()
	_build_category_buttons()
	_rebuild_item_grid()


# 「ショップ」見出しを木札風に。雑貨店の入口看板イメージ。
func _style_title_panel() -> void:
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = TITLE_PANEL_BG
	sbox.border_color = TITLE_PANEL_BORDER
	sbox.set_border_width_all(1)
	sbox.set_corner_radius_all(4)
	sbox.content_margin_left = 18
	sbox.content_margin_right = 18
	sbox.content_margin_top = 8
	sbox.content_margin_bottom = 8
	sbox.shadow_color = TITLE_PANEL_SHADOW
	sbox.shadow_size = 4
	sbox.shadow_offset = Vector2(1, 2)
	title_panel.add_theme_stylebox_override("panel", sbox)
	var title_label := title_panel.get_child(0) as Label
	if title_label != null:
		title_label.add_theme_color_override("font_color", TITLE_PANEL_FONT)


# --- カテゴリバー -------------------------------------------------------

func _build_category_buttons() -> void:
	_category_group = ButtonGroup.new()
	_category_buttons.clear()
	for child in category_bar.get_children():
		child.queue_free()
	for entry in CATEGORY_ENTRIES:
		var b := _make_category_button(entry.label_key, entry.value)
		category_bar.add_child(b)
		_category_buttons[entry.value] = b
	# 初期選択
	var initial: Button = _category_buttons.get(_selected_category)
	if initial != null:
		initial.set_pressed_no_signal(true)


func _make_category_button(label_key: String, cat: int) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = _category_group
	b.text = label_key  # Button.text は翻訳キーで自動 tr 追従
	b.add_theme_stylebox_override("normal", _make_cat_stylebox(CAT_BTN_BG))
	b.add_theme_stylebox_override("hover", _make_cat_stylebox(CAT_BTN_BG_HOVER))
	b.add_theme_stylebox_override("pressed", _make_cat_stylebox(CAT_BTN_BG_ACTIVE, true))
	b.add_theme_stylebox_override("focus", _make_cat_stylebox(CAT_BTN_BG_HOVER))
	# トグル ON 時の見た目を pressed と揃える
	b.add_theme_stylebox_override("hover_pressed", _make_cat_stylebox(CAT_BTN_BG_ACTIVE, true))
	b.add_theme_color_override("font_color", CAT_BTN_INK)
	b.add_theme_color_override("font_pressed_color", CAT_BTN_INK_ACTIVE)
	b.add_theme_color_override("font_hover_color", CAT_BTN_INK_ACTIVE)
	b.custom_minimum_size = Vector2(0, 36)
	b.pressed.connect(_on_category_pressed.bind(cat))
	return b


func _make_cat_stylebox(bg: Color, active: bool = false) -> StyleBoxFlat:
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = bg
	sbox.border_color = CAT_BTN_BORDER
	sbox.set_border_width_all(1)
	# 「タブの見出し」感を出すため、選択中は下角を平らに（紙が下に続いている表現）
	sbox.corner_radius_top_left = 6
	sbox.corner_radius_top_right = 6
	sbox.corner_radius_bottom_left = 0 if active else 6
	sbox.corner_radius_bottom_right = 0 if active else 6
	sbox.content_margin_left = 14
	sbox.content_margin_right = 14
	sbox.content_margin_top = 6
	sbox.content_margin_bottom = 6
	if active:
		sbox.shadow_color = Color(0, 0, 0, 0.35)
		sbox.shadow_size = 3
		sbox.shadow_offset = Vector2(0, 2)
	return sbox


func _on_category_pressed(cat: int) -> void:
	if _selected_category == cat:
		return
	_selected_category = cat
	_rebuild_item_grid()


# --- 商品グリッド -------------------------------------------------------

func _rebuild_item_grid() -> void:
	for child in item_grid.get_children():
		child.queue_free()
	_cards.clear()

	var items: Array = []
	for it: ItemData in DataRegistry.get_items_by_category(_selected_category):
		# メタ強化によるゲート：requires_meta が未解放なら陳列しない
		if it.requires_meta != &"" and not GameState.has_meta_unlock(it.requires_meta):
			continue
		items.append(it)
	# 価格昇順で並べる（買いやすい順 = 棚の手前から）
	items.sort_custom(func(a: ItemData, b: ItemData) -> bool: return a.price < b.price)

	empty_label.visible = items.is_empty()
	for it: ItemData in items:
		var card := _card_factory.build(it)
		item_grid.add_child(card)
		_cards[it.id] = card
		_card_factory.refresh(card, it)


func _refresh_all_cards(_v: int = 0) -> void:
	for id in _cards.keys():
		var it := DataRegistry.get_item(id)
		if it != null:
			_card_factory.refresh(_cards[id], it)


# --- イベントハンドラ ---------------------------------------------------

func _on_buy_requested(id: StringName, qty: int) -> void:
	ShopService.buy(id, qty)


func _on_item_purchased(id: StringName) -> void:
	var card: PanelContainer = _cards.get(id)
	if card != null:
		var it := DataRegistry.get_item(id)
		if it != null:
			_card_factory.play_purchase_feedback(card, it)
	_refresh_all_cards()


func _on_inventory_changed(id: StringName, _new_count: int) -> void:
	var card: PanelContainer = _cards.get(id)
	if card == null:
		return
	var it := DataRegistry.get_item(id)
	if it != null:
		_card_factory.refresh(card, it)


func _on_meta_upgrade_purchased(_meta_id: StringName, _new_level: int) -> void:
	_rebuild_item_grid()


# --- i18n ---------------------------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		# カテゴリボタンは Button.text に翻訳キーが入っているので Godot が自動再翻訳する。
		# カード側は tr() 経由で組み立てた文言を含むため、明示的に貼り直し＋数値再描画する。
		for id in _cards.keys():
			var it := DataRegistry.get_item(id)
			if it == null:
				continue
			_card_factory.rebuild_static_text(_cards[id], it)
		_refresh_all_cards()
