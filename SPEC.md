# Clicker Game Demo — 仕様書

アークナイツ二次創作の紳士向けクリッカーゲーム。Godot 4.6+ で構築。

このドキュメントは「**何ができるか**」「**どう拡張するか**」「**コードのどこに何があるか**」をまとめたもの。

---

## 1. ゲームコンセプト

| 軸 | 内容 |
|---|---|
| ジャンル | クリッカー × 育成 × ギャラリー × 紳士枠 |
| プレイ時間 | 2〜5時間で完走 |
| 対象 | 1〜3キャラ（レミュアン／ニェン／ブレイズ予定）|
| コアループ | クリック→通貨→ショップ購入→Roomで使う→信頼度UP→新コンテンツ解放 |

### 3タブ構成（L字レイアウト）

| タブ | 役割 | 主機能 |
|---|---|---|
| **Work** | 通貨生成 | 書類クリック、強化購入 |
| **Room** | キャラ触れ合い | 立ち絵、ギフト、タッチ、検査、紳士眼鏡、Memory |
| **Shop** | アイテム購入 | カテゴリ別ショップ、衣装、ルール、紳士眼鏡 |

---

## 2. アーキテクチャ

```
┌──────────────────────────────────────────────────────────┐
│ UI 層 (タブ毎・互いに参照禁止)                           │
│  scenes/ui/{work,room,shop}_tab.tscn                     │
│  scripts/ui/{work,room,shop}_tab.gd                      │
└──────────────┬─────────────────────────────────┬─────────┘
               │ Service 呼び出し                │ シグナル受信
               ↓                                 ↑
┌──────────────────────────────────────────────────────────┐
│ Service 層（純粋関数・state は GameState 経由のみ）      │
│  EconomyService / ShopService / GiftService              │
│  TouchService / InspectionService / ScopeService         │
│  ReactionResolver                                        │
└──────────────┬─────────────────────────────────┬─────────┘
               ↓ state 書換                      ↑ 通知発火
┌──────────────────────────────────────────────────────────┐
│ Autoload 層                                              │
│  ・GameState     進行状態の唯一の真実                    │
│  ・DataRegistry  data/*.tres をロード＆idルックアップ    │
│  ・EventBus      全タブ横断シグナル（疎結合の要）        │
│  ・LocaleService locale 切替                             │
└──────────────────────────────────────────────────────────┘
                         ↑ 起動時ロード
┌──────────────────────────────────────────────────────────┐
│ Data 層 (.tres マスタ)                                   │
│  data/operators/  data/items/  data/costumes/            │
│  data/reactions/  data/scopes/  data/upgrades/  ...      │
└──────────────────────────────────────────────────────────┘
```

### 疎結合の原則

- UI同士は直接参照しない（`get_node("../OtherTab")` 禁止）
- UI → Service → GameState → EventBus → UI の一方通行
- 新コンテンツ追加は **`.tres` を置くだけ**でよい

---

## 3. ディレクトリ構成

```
project.godot              autoload + i18n 設定
README.md / SPEC.md
icon.svg                   プロジェクトアイコン
assets/
  paperwork.svg           Work タブのクリック対象
  operators/<op>_*.svg    立ち絵（normal / xray_<kind> / pose）
data/
  operators/              OperatorData (.tres)
  costumes/               CostumeData (.tres)
  items/                  ItemData (.tres)
  scopes/                 ScopeData (.tres)
  upgrades/               UpgradeData (.tres)
  reactions/              ReactionRule (.tres)
  cgs/ memories/ messages/ touch_spots/
scripts/
  autoload/               EventBus, GameState, DataRegistry, LocaleService
  data/                   Resource クラス定義
  services/               純粋ロジック層
  ui/                     タブ別 UI スクリプト + UIConstants + ThemeFactory
scenes/
  main.tscn               L字レイアウト枠
  ui/                     タブ毎 .tscn
translations/
  strings.csv             翻訳テーブル（key, ja, en）
```

---

## 4. データモデル

### OperatorData

オペレータ定義。1人=1ファイル。

| field | 型 | 用途 |
|---|---|---|
| `id` | StringName | 一意ID |
| `display_name` | String | 翻訳キー or リテラル |
| `personality` | Enum | SAINTLY_DUAL / ANCIENT_FREE / SISTERLY_TEASE |
| `origin` | StringName | 出身（好物分岐用）|
| `liked_items` / `disliked_items` | Array[StringName] | 好物・嫌い |
| `default_costume_id` | StringName | 起動時に着用 |
| `stages` | Array[TrustStageData] | 5段階の閾値 |
| `unlock_cost` | int | 0=最初から、>0=招待状ゲート |
| `portrait_idle` | Texture2D | アイドル立ち絵 |
| `portrait_expressions` | Dictionary | 表情差分 `{"blush": tex, ...}` |
| `xray_detection_rate` | float | 紳士眼鏡で気付かれる速度倍率 |

### CostumeData

衣装。OperatorData と多対1。

| field | 用途 |
|---|---|
| `sprite` | 通常立ち絵 |
| `sprite_pose_seductive` | 高信頼で気付かれた時の見せつけ |
| `sprite_xray_variants: Dictionary` | キー=`view_kind`、値=透過版テクスチャ |

### ScopeData

紳士眼鏡（=透視枠）。

| field | 用途 |
|---|---|
| `view_kind` | StringName。CostumeData の `sprite_xray_variants` を引くキー |
| `battery_max_sec` | 1充電あたり使用可能時間 |
| `suspicion_rate` | バレやすさ倍率（低=ステルス）|
| `resolution_level` | 後でシェーダ用 |
| `frame_overlay` | 将来「四角枠」を画面に重ねるとき用 |

### ItemData / ItemEffect

ショップアイテム。`effects: Array[ItemEffect]` で複数効果を持つ。

`ItemEffect.kind` の対応：
- `TRUST_ADD` ギフトでの信頼度加算
- `CG_UNLOCK` CG解放
- `OPERATOR_UNLOCK` 招待状でオペ解放
- `COSTUME_UNLOCK` 衣装解放
- `HARASSMENT_LOCK` ハラスメントカウンタ加算
- `RULE_ACTIVATE` ルール有効化（検査の建前）
- `SCOPE_BATTERY_REFILL` 紳士眼鏡の電池補充
- `SCOPE_GRANT` 紳士眼鏡を付与

### ReactionRule

「**何が起きたとき、誰が、どんな反応をするか**」の1行。データ駆動の核。

| field | 用途 |
|---|---|
| `trigger_kind` | ITEM / TOUCH / HARASSMENT / **INSPECTION** / **XRAY_CAUGHT** |
| `trigger_id` | item_id or touch_spot_id（空なら category マッチ）|
| `operator_id` | 空＝全キャラ共通 |
| `match_category` | true なら `category` でマッチング |
| `min_trust` / `max_trust` | 信頼度ゲート |
| `consecutive_count_min/max` | 連続贈与回数ゲート（媚薬連投ドン引き等）|
| `requires_active_rule` | 空＝ゲートなし、非空＝そのルール所持時のみマッチ |
| `reaction` | 反応種別（DELIGHTED / SHY / DOMINATED / ...）|
| `trust_delta` | 信頼度変化量 |
| `expression` | 立ち絵表情キー |
| `dialogue` | 台詞（翻訳キー）|
| `side_effects` | 追加 ItemEffect（CG解放、ロック等）|
| `priority` | 高い方が優先採用 |

### OperatorRuntime

ランタイム状態（永続セーブ対象）。

```
trust, current_stage
equipped_costume, unlocked_costumes
gift_history (item_id -> 回数)
harassment_counter, locked_until
last_inspection_unix
xray_suspicion
```

---

## 5. 機能仕様

### 5.1 通貨・強化（Work タブ）

- 書類クリックで通貨+`click_power`
- `AutoTimer` 1秒毎に通貨+`per_second`
- アップグレード購入で各値が増える
  - `UpgradeData.effect_kind`: ADD_CLICK / ADD_PER_SEC / MULT_CLICK
  - コストは `base_cost * pow(growth, level)`

### 5.2 ギフト（Room タブ）

```
GiftService.give(op_id, item_id)
  → 在庫消費 → ReactionResolver で反応引く
  → 信頼度更新 → side_effects 適用 → reaction_played 発火
```

連続贈与回数は `gift_history` に蓄積、`consecutive_count_min/max` で反応分岐。

### 5.3 タッチ（Room タブ）

- `TouchSpotData` で各部位を定義（`is_harassment` で通常/セクハラ判別）
- `unlock_at_stage` 未満の段階だと押せない
- セクハラタッチ → `harassment_counter` 加算 → 閾値で **5分ロック**

### 5.4 身だしなみ検査（Room タブ）

```
InspectionService.inspect(op_id)
  → クールダウン中なら toast
  → mark_inspected で時刻記録
  → ReactionResolver(INSPECTION) で反応引く
```

**建前装置の使い方：**

1. Shop で `rule_underwear_mandate` を購入 → `RULE_ACTIVATE` で `active_rules` に追加
2. 検査ボタン押下 → ReactionRule 検索時、`requires_active_rule = "rule_underwear_mandate"` がマッチ
3. **ペナルティ無し＋専用ダイアログ**で合法化

クールダウン: `UIConstants.INSPECTION_COOLDOWN_SEC`（既定 300秒、テスト時短縮可）。

### 5.5 紳士眼鏡（Room タブ）

```
ScopeService.toggle(op_id)
  → ON: バッテリー消費開始、立ち絵を sprite_xray に切替
ScopeService.tick(delta, op_id)  ← 毎フレーム
  → バッテリー減少
  → suspicion += rate * scope.suspicion_rate * op.xray_detection_rate * delta
  → suspicion >= XRAY_SUSPICION_THRESHOLD で _trigger_caught()
```

**バレ判定の3分岐**（ReactionRule で書く）：

| trust | reaction | 効果 |
|---|---|---|
| 低 | REJECTED | 信頼度大幅減＋ロック発動 |
| 中 | SHY | 軽い信頼度減 |
| **高** | **DOMINATED** | 信頼度+α、見せつけポーズ表示（`sprite_pose_seductive`、N秒）|

**枠（view_kind）の拡張**：
新しい透視タイプを追加 = `ScopeData.view_kind = &"thermal"` の `.tres` を作り、各 `CostumeData.sprite_xray_variants[&"thermal"]` に画像を入れるだけ。

候補: `underwear` / `nude` / `swimsuit` / `thermal` / `mood`

### 5.6 統合ルート（紳士枠の核）

> 「下着義務化命令」+ 「紳士眼鏡 ON」+ 「身だしなみ検査」 = **建前完備の合法覗き**

これは ReactionRule で表現可能：

```
trigger_kind = INSPECTION
operator_id = lemuen
requires_active_rule = rule_underwear_mandate
min_trust = 80
priority = 200
reaction = DOMINATED
side_effects = [CG_UNLOCK target=cg_lemuen_compliant_inspection]
dialogue = "DIALOGUE_LEMUEN_INSP_COMPLIANT_HIGH"
```

---

## 6. UI 共通定数

`scripts/ui/ui_constants.gd` が**唯一の真実**。

- フォントサイズ → `FONT_DISPLAY` / `FONT_TITLE` / `FONT_BODY` etc
- 余白 → `SEP_SMALL` / `SEP_DEFAULT` / `SEP_WIDE` etc
- 色 → `COLOR_BG` / `COLOR_ACCENT` etc
- アニメ時間 → `TOAST_HOLD_SEC` / `PORTRAIT_CLICK_DURATION` etc
- ゲームバランス → `INSPECTION_COOLDOWN_SEC` / `XRAY_SUSPICION_THRESHOLD` etc
- Theme variation 名 → `VAR_DISPLAY_BUTTON` / `VAR_TITLE_LABEL` etc

`scripts/ui/theme_factory.gd` が UIConstants から Theme を組み立てて Main の theme に入れる。`.tscn` 側は `theme_type_variation = &"DisplayButton"` で参照。

---

## 7. 翻訳（i18n）

`translations/strings.csv` に key + 言語列。

- 静的 .tscn：`text = "UI_KEY"`（auto_translate）
- 動的コード：`tr("UI_KEY")`
- Resource フィールド：キーを入れて `tr(op.display_name)` で解決
- 静的メソッド：`TranslationServer.translate("KEY")`（Object に `tr()` が無いため）

新言語追加：CSV に列追加 → `LocaleService.SUPPORTED_LOCALES` に追加 → `project.godot` の `locale/translations` に追加 → エディタで再インポート。

---

## 8. 拡張ガイド

### 新キャラを追加

1. `assets/operators/<id>_default.svg` 等の立ち絵を置く
2. `data/operators/<id>.tres` を作る（`unlock_cost > 0` で招待状ゲート）
3. `data/costumes/<id>_default.tres` を作る
4. `data/reactions/<id>_*.tres` で反応ルールを書く
5. `translations/strings.csv` に名前・台詞のキーを追加
6. **コード変更ゼロで新キャラが Room に出る**

### 新アイテムを追加

1. `data/items/<id>.tres` を作る（`category` と `effects` を設定）
2. ルール系なら `kind = RULE_ACTIVATE`、紳士眼鏡なら `SCOPE_GRANT` 等
3. **Shop タブのカテゴリ別リストに自動で並ぶ**

### 新 Scope（透視タイプ）を追加

1. `data/scopes/<id>.tres` を作る（`view_kind = &"new_type"`）
2. 各 CostumeData の `sprite_xray_variants[&"new_type"]` に画像を入れる
3. `data/items/scope_<id>_item.tres` を作って `SCOPE_GRANT` 効果でグラント
4. **コード変更ゼロ**

### 新反応を追加

`data/reactions/*.tres` を1個作るだけ。`priority` を高くすれば既存ルールを上書き可能。

---

## 9. テスト用データ（同梱）

- **OperatorData**: `lemuen`（5段階、自動解放）
- **CostumeData**: `lemuen_default`（normal / xray_underwear / pose）
- **ItemData**: `tea_premium`（ギフト）/ `rule_underwear_mandate`（ルール）/ `scope_basic_item`（眼鏡）/ `scope_battery`（電池）
- **ScopeData**: `scope_basic`（view_kind=underwear, battery=30s）
- **ReactionRule**: 5本（ギフト紅茶 / 検査拒否 / 検査合法 / X線低信頼 / X線高信頼）
- **UpgradeData**: `click_plus_one`（+1 クリック強化）

### 動作確認シナリオ

1. Work タブで書類連打 → 通貨が貯まる
2. Shop で `tea_premium` 購入 → Room で渡す → 反応＋信頼度+6
3. Shop で `rule_underwear_mandate` 購入 → 検査ボタン押下 → ペナ無し
4. Shop で `scope_basic_item` + `scope_battery` 購入 → Room で 👓 ON → 立ち絵が xray 版に切替 → 30秒消費
5. ON のまま放置 → suspicion 満タンで XRAY_CAUGHT 発火 → 反応表示

---

## 10. 残課題 / 拡張余地

- [ ] セーブ / ロード（`user://save.json`）
- [ ] Memoryシーン再生UI（ノベル風プレイヤー）
- [ ] 向こうから話しかけ（`IncomingMessage` ベース）
- [ ] アニメーション・効果音・パーティクル
- [ ] 残り2キャラ（ニェン / ブレイズ）データ
- [ ] 高解像度の本物アセット
- [ ] `view_kind` 追加（thermal, nude, mood 等）
- [ ] 紳士眼鏡の強化系（高耐久・低 suspicion・高解像度）
- [ ] 統合ルート（眼鏡+検査+ルール）の専用 ReactionRule と CG 追加
