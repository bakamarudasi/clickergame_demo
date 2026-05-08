# プロジェクト状態スナップショット — 2026-05-08

> Lemuen 1 体ぶんのコンテンツ全部 + エンジン土台が完成した時点での状態。

---

## 1. ハイライト

- **エンジン側ほぼ完成**：反応 / ゲート / 立ち絵 / HCG ビューア / Shop / アイドル / バフ、全部実装済み。
- **Lemuen 1 体で 250 弱の翻訳キー**が ja/en/zh_CN 100% 完備。
- **CG 4 本** ぶんのスクリプト確定（合計 137 ステップ）。画像は null だがプレースホルダで再生確認可能。
- **次のキャラ追加コストが最小**：既存テンプレに沿ってデータ追加するだけ。

---

## 2. 数値スナップショット

| 項目 | 値 |
|---|---|
| データ + コードファイル数（.gd/.tscn/.tres/.csv 計）| 159 |
| Lemuen 翻訳キー（ja/en/zh_CN 全埋め）| 231 |
| 共通 UI 翻訳キー | 148 |
| 反応ルール `.tres` 件数 | 62 |
| CG `.tres` 件数 | 4 |
| タッチスポット `.tres` 件数 | 15 |
| トリガー種類（Enums.TriggerKind） | 10（ITEM / TOUCH / HARASSMENT / INSPECTION / XRAY_CAUGHT / STAGE_UP / PRESTIGE / AROUSAL_MAX / LOCKED_REVISIT / IDLE） |
| サポート言語 | ja, en, zh_CN |

---

## 3. 実装済み機能

### 3.1 反応システム

- ResolveResolver で priority + specificity による自動選択
- 全 10 種 TriggerKind の発火パイプライン
- ゲート種別（min/max 各種）：
  - `min_trust` / `max_trust`
  - `min_intimacy` / `max_harassment`
  - `min_tier`（プレステージ周回数）
  - `min_bond`
  - `min_arousal`
  - `consecutive_count_min/max`（累積回数 — マイルストーン CG 用）
  - `requires_equipped_costume`
  - `requires_xray_active`
  - `requires_active_rules`（ルール item 効果）
  - `requires_cgs` / `requires_memories`
  - `probability`（確率発火）
- `dialogue_alternates`：同一ルール内ランダム台詞ローテ
- side_effects：CG_UNLOCK / TRUST_ADD / AROUSAL_ADD / MEMORY_UNLOCK / OPERATOR_UNLOCK / COSTUME_UNLOCK / HARASSMENT_LOCK / RULE_ACTIVATE / SCOPE_GRANT / SCOPE_BATTERY_REFILL

### 3.2 立ち絵システム（ハイブリッド）

- **静的方式**：CostumeData.sprite + portrait_expressions（全身差し替え）/ portrait_face_overlays（顔差分レイヤー）
- **face_anchor_rect** でコスチュームごとの顔位置調整
- **portrait_scene スロット**：Spine / Live2D / AnimationPlayer rig 用
- 発情度連動の桜色 modulate tint
- 反応時の表情フラッシュ（2.5秒）
- xray ON 時の透視差分

### 3.3 HCG ビューア

- 全画面オーバレイ Scene
- PORTRAIT モード（立ち絵 + 顔差分 + 台詞ボックス）
- FULL_CG モード（全画面イラスト + 台詞ボックス）
- CGStep 列でクリック進行
- 画像 null 時はプレースホルダ表示
- BGM / SFX スロット
- `cg_unlocked` シグナルで自動ポップアップ

### 3.4 Room タブ

- オペ一覧（左）/ 立ち絵（中）/ 詳細パネル（右）
- 信頼度・親密度・発情度ゲージ
- 会話エリア（直近10件・自動スクロール）
- ギフト選択 / タッチスポット / 検査ボタン / 紳士眼鏡 ON-OFF
- アイドルカウントダウン → 6 分でクリック ×2 バフ

### 3.5 Shop タブ

- カテゴリ別アイテム一覧
- 詳細パネル（説明 / 価格 / 信頼ゲート）
- **数量買い ×1 / ×10 / ×100 / ×Max**
- 通貨変動の即時反映

### 3.6 Work タブ

- クリックで通貨獲得（クリックバフ込み）
- アップグレード購入（指数価格成長）
- ゴールデン書類（3〜7分間隔ランダム発火）→ 通貨ボーナス

### 3.7 サブシステム

- プレステージ（永続強化、reset on prestige）
- 紳士眼鏡（xray view kind / battery / suspicion）
- ハラスメントロック（不正行為で操作不能）
- メッセージ機能（IncomingMessage、未活用）
- ルール system（rule_underwear_mandate 等）
- 翻訳ホットスワップ（locale 切替即時反映）

---

## 4. Lemuen コンテンツ詳細

### 4.1 反応カテゴリ（ja/en/zh_CN 全完備）

| カテゴリ | 件数 | 備考 |
|---|---|---|
| ギフト × 8 アイテム × 各複数段 | 33 行 | tea / vibrator / oil / rope / gas / novel / bracelet / catears / med_protector |
| ゴム特殊（PROT_T0/T1/T1_SEEN/T2 + マイル100/500/1000） | 7 行 | T1 が初夜 CG 解放、マイル各 CG 解放 |
| タッチ（13 通常 + 2 ハラス）× 各 1〜3 alt | 43 行 | 髪 / 手 / 頭 / 肩 / 耳 / 抱擁 / 太もも / 腰 / 胸服 / キス / 胸直 / キス深 / 下半身 / 強引 / 胸グロープ |
| 検査 | 5 行 | reject / compliant / underwear T0/T1/T2 |
| 紳士眼鏡 | 2 行 | low / high |
| 深夜検査 | 3 行 | midnight ランダム alt |
| ステージ昇格 | 4 行 | 警戒→様子見→打ち解け→親密→陥落の 4 遷移 |
| プレステージ再会 | 1 行 | 周回後初対面 |
| 発情度 MAX | 1 行 | arousal == AROUSAL_MAX 1 度 |
| ロック中再訪問 | 2 行 | ハラス後の再アクション |
| アイドル 4 段 | 4 行 | 1分 / 3分 / 5分 / 6分（fire + クリックバフ）|
| **CG_GOMU 初夜** | **52 行** | medical_protector T1 解放 |
| **CG_HABIT 習慣化** | **25 行** | medical_protector 累計 100 |
| **CG_DEVOTE 観察結果** | **32 行** | medical_protector 累計 500 |
| **CG_BREAK 誓約** | **28 行** | medical_protector 累計 1000 |

**合計 231 翻訳キー**（重複なし、231 = 全データ整合）

### 4.2 タッチスポット（15 個）

| スポット | 解禁ステージ | カテゴリ |
|---|---|---|
| 髪を撫でる | 0 | 軽 |
| 手を取る | 1 | 軽 |
| 頭をぽんぽん | 1 | 軽（逆襲対象）|
| 肩・首筋 | 2 | 中 |
| 耳元で囁く | 2 | 中 |
| 抱きしめる | 2 | 中 |
| 太もも | 3 | 強 |
| 腰 | 3 | 強 |
| 胸（服越し） | 3 | 強 |
| 唇キス | 3 | 強 |
| 胸（直接） | 4 | H |
| 唇（深く） | 4 | H |
| 下半身 | 4 | H |
| ⚠ 強引な接近 | 0 | ハラス |
| ⚠ いきなり胸 | 0 | ハラス |

### 4.3 CG 解放フローチャート

```
[初期状態]
   ↓ medical_protector を渡す（ゴム 1 個目、prestige≥1, trust≥60）
   ↓
[CG「初夜」解放（cg_lemuen_intimate_first / 52 ステップ）]
   ↓ ゴム 100 個目（accumulative）
   ↓
[CG「習慣化」解放（cg_lemuen_intimate_habit / 25 ステップ）]
   ↓ ゴム 500 個目
   ↓
[CG「観察結果」解放（cg_lemuen_intimate_devote / 32 ステップ）]
   ↓ ゴム 1000 個目
   ↓
[CG「誓約」解放（cg_lemuen_intimate_break / 28 ステップ）] ← FINAL
```

各マイルストーン到達時に該当 CG が自動全画面再生。閉じても CGViewer に保存（次回ギャラリー UI から再生可能・予定）。

---

## 5. ペンディング項目

### 5.1 素材待ち（実装は完了している）

- 🎨 **画像 26 枚**：Lemuen 立ち絵 + 表情差分 + CG イラスト 26（詳細は `ASSET_LIST.md`）
- 🔊 **BGM / SFX**：枠あり、null 許容
- 🎨 **アイテムアイコン 22 枚**（任意）

### 5.2 残タスク（実装必要）

| 項目 | 規模 | 優先 |
|---|---|---|
| ギャラリー UI（Status タブを CG/Memory ビューに） | 中 | ⭐ 高 |
| セーブ／ロード（user://save.json） | 中 | ⭐ 高（README で TODO 扱い） |
| 別オペレーター追加（テンプレ完成済み） | 大 | 中 |
| アイドル代案（ラテラーノ式爆発・逆スキンシップ） | 中 | 低 |
| Memory システム（CG とは別軸の思い出枠） | 中 | 低 |
| B パック（公式設定回収：アンドアイントラウマ等） | 中 | 低 |

### 5.3 既知の小ネタ

- xray 透視のテクスチャがコスチューム単位で空（`sprite_xray_variants` 全 null）
- 検査クールダウン UI が時間表示固定（時刻表示があると better）
- Memory_unlocked シグナル発火経路あり、Memory データ枠なし

---

## 6. 主要ファイルマップ

```
data/
├── cgs/                             # CGData × 4
├── costumes/                        # CostumeData × 1（lemuen_default）
├── items/                           # ItemData × 22
├── operators/                       # OperatorData × 1（lemuen）
├── reactions/                       # ReactionRule × 62
├── shop_categories/
├── touch_spots/                     # TouchSpotData × 15
├── upgrades/                        # UpgradeData × 7
└── ...

scripts/
├── autoload/                        # EventBus / DataRegistry / GameState / LocaleService
├── data/                            # Resource クラス定義
├── services/                        # Touch / Gift / Inspection / Shop / Scope / Reaction / Economy
└── ui/                              # main / room_tab / work_tab / shop_tab / status_tab / cg_viewer

scenes/
├── main.tscn
└── ui/
    ├── room_tab.tscn               # 大改修済み・PortraitView + FaceOverlay 含む
    ├── work_tab.tscn
    ├── shop_tab.tscn               # 数量ボタン追加済み
    ├── status_tab.tscn
    └── cg_viewer.tscn

translations/
├── strings.csv                     # UI 共通 148 行
└── dialogues/
    └── lemuen.csv                  # 231 行（ja/en/zh_CN 100%）

docs/
├── ASSET_LIST.md                   # 制作画像リスト（このコミットで新規）
├── PROJECT_STATUS_2026-05-08.md    # この文書
├── PROGRESSION.md                  # ステージ・反応設計
└── SPEC.md                         # システム仕様
```

---

## 7. ブランチ状況

```
ブランチ: claude/testing-free-enhancements-QEZuv
直近コミット（過去 25 件）:
  a9807a0 i18n: complete en / zh_CN translation pass for Lemuen (223 lines)
  a9b970a Shop bulk-buy: ×1 / ×10 / ×100 / ×Max quantity selector
  8f91205 Milestone CGs: gomu 100/500/1000 unlock progressive scenes
  86a3dc6 gomu repeat give: stop replaying T1 line after CG seen
  4b4fe97 Expand gomu first-night CG to full 52-step script
  a301600 HCG viewer: step-based CG playback + cg_unlocked auto popup
  a8413c2 Idle countdown: Lemuen sniper flavor + click buff on fire
  6d1acdb Pack A: stage-up, prestige reunion, locked-revisit, arousal-max events
  dceca42 Add portrait_scene slot for Spine / Live2D / scene-based portraits
  9f41807 Add layered face-overlay portraits alongside full-swap expressions
  47af00c Add dialogue_alternates pool + 55 new Lemuen lines
  c816461 Add 15 Lemuen touch spots
  9c6fec3 Split character dialogue strings into per-operator CSVs
  49bae86 Tune Golden Paperwork
  bb51d7d Add Golden Paperwork
  b33fa87 Overhaul Room tab
  d5f6cc0 Add condom 3-tier reaction set + first intimate CG
  ...
```

---

## 8. 次の作業選択肢

1. **画像 26 枚を作る** → `ASSET_LIST.md` の優先順位順
2. **ギャラリー UI（Status タブ）** → CG 再生済みコンテンツの再生入口
3. **セーブ／ロード** → 進捗保存（プレステージ周回が現状リロードで消える）
4. **新キャラ追加** → テンプレ済み（OperatorData + 反応 + 翻訳）
5. **B パック（キャラ深化）** → アンドアイントラウマ / 車椅子改造アイドル / 呼称シフト

---

**結論**：Lemuen 1 体ぶんの **「ゲームとして完成しうる最小単位」** に到達。残りは素材 or 量産 or QoL 系。
