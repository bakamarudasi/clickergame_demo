# Progression Design — Shop / Prestige / Reaction Tiers

クリックで稼ぐ → ショップで買う → ルームでオペに使う → 反応・信頼度→ プレステージ → メタ強化 → 周回。
このサイクル全体の設計をまとめたドキュメント。`SPEC.md` の補完として読む。

---

## 1. ショップ設計

### 1.1 役割分担

| 機能 | 役割 |
|---|---|
| **Workタブの強化** | 通貨生成効率を上げる（クリック威力・自動収益・倍率） |
| **Shopタブのアイテム** | キャラ交流のための消耗品・装備・規則・解放アイテム |
| **プレステージのメタ強化** | 周回時の永続バフと、新カテゴリ強化の解放 |

つまり Shop は **「クリック→お金→キャラに何かしてあげる」** の中継地点であって、能力強化はここでは扱わない。

### 1.2 カテゴリ別商品ラインナップ（指針）

既存 `Enums.ItemCategory` に沿う。各 .tres は `data/items/` に置くだけで Shop に並ぶ。

| カテゴリ | 役割 | 商品例 | 主な効果 |
|---|---|---|---|
| **DAILY** 日常 | 安価な消耗ギフト | 紅茶 / コーヒー / クッキー / 弁当 | 信頼度+小、繰り返し購入可 |
| **HOBBY** 趣味 | キャラ依存の中価格ギフト | 古い書物 / 戦術論文 / 編み物道具 | 信頼度+中、対象キャラ以外は反応薄 |
| **BODY_CARE** ボディケア | 距離詰めの建前 | バスソルト / マッサージオイル / ローション | TouchSpot 解放、xray 反応を変化 |
| **ROMANCE** ロマン | マイルストーン用 | 花束 / 銀のブレスレット / 指輪 | 信頼度+大、ステージ進行のキー |
| **DIRECT_TOY** 玩具 | 紳士枠 | バイブ / ローター / クリップ類 | 専用 TouchSpot / 反応 / CG 解放 |
| **DIRECT_DRUG** 薬品 | リスク系 | 媚薬 / 催眠ガス / 弱体剤 | 一時バフ・デバフ＋発覚リスク |
| **DIRECT_BIND** 拘束 | シーン専用 | ロープ / 手錠 / 目隠し | 拘束シナリオ解放、専用 Memory |
| **DIRECT_PROT** 保護 | 後始末 | コンドーム / 薬 / 言い訳手帳 | 発覚率減・連続行為許可 |
| **COS_OUTFIT** 衣装 | 立ち絵差し替え | 私服 / メイド服 / 水着 / 拘束衣 | CostumeData 切替、CG 分岐 |
| **COS_PARTS** パーツ | 部分着せ替え | 猫耳 / チョーカー / 網タイツ | スタック可能アクセ枠（後日） |
| **INVITATION** 招待状 | イベント解放（消費型） | お茶会招待 / 検査室招待 / 夜の散歩 | Memory/CG シーン1本解放、消費 |
| **RULE** 規則 | 環境改変（永続） | 下着義務化 / 検査時間外通達 / 報告書徹夜命令 | 永続フラグ、検査・反応の前提を変える |
| **SCOPE** 眼鏡 | 能力拡張 | 基本 / 上位（服透視）/ 改造（思考読み）/ 電池 | xray 枠の段階的解放 |

### 1.3 DIRECT 系（紳士枠）の解放方針

**ショップ陳列はステージ非依存。買うのは自由、渡すのも基本自由。**
そのうえで **二段ゲート** で受け入れ反応をコントロールする。

| 軸 | 何をゲートするか | 反応イメージ |
|---|---|---|
| **信頼度ステージ** | ステージ未到達では **強い拒絶**（`LOCKED_OUT` 系）。「あなた、何を考えているの？」 | 物語的な土台が無い |
| **プレステージ周回** | ステージ条件は満たすが **周回不足** → やんわり受け流される。「まだ早いね、ドクター」 | 関係はあるが、まだ踏み込めない |
| **両方クリア** | 受け入れ → CG/Memory 解放 | 「そんな…でもドクターが言うなら」 |

→ **「買えるけど断られる」** という焦らしを 2 段で重ねる。
ステージは「物語の進行」、プレステージは「周回ご褒美の解放軸」。

#### 具体例: ゴム（DIRECT_PROT）

| 周回 | ステージ < 3 | ステージ 3 | ステージ 4 |
|---|---|---|---|
| **1周目（prestige=0）** | 拒絶 | やんわり拒否「まだ早いね、ドクター」 | やんわり拒否（態度はやや動揺） |
| **2周目（prestige=1）** | 拒絶 | 受け入れ「そんな…でもドクターがどうしてもって言うなら」+ **CG 解放** | 受け入れ |
| **3周目以降** | 拒絶 | 慣れ「また？　ふふ、もう手慣れたものね」 | 慣れ |

これは ReactionRule の `min_trust` + `min_tier` 組み合わせで全部表現できる（後述 §3）。
**プレステージはストーリーをやり直すのではなく「踏み込める範囲が広がる」軸として機能する。**

### 1.4 INVITATION の扱い

**消費型**（1回使うと無くなる）。レア感を出す。
ItemEffect で対応する Memory シーンを解放しつつ、所持数を1減らす処理を `ShopService` 側に追加する必要あり（現状は所持数管理がない場合は併せて整備）。

### 1.5 CG 解放の責務分担

CG 解放のトリガーは **ReactionRule の `side_effects` で `CG_UNLOCK` を発火**するのが基本。
プレステージ周回での解放は、`min_tier` 付きの ReactionRule がその tier で初めて発火する形で表現する。

| 解放経路 | 例 |
|---|---|
| ステージ昇格時に自動解放 | 既存の OperatorData 進行ベース |
| アイテム使用時のリアクションで解放 | 紅茶ギフト → CG_LEMUEN_TEA |
| **プレステージ周回 N 到達時に新ルートが解放** | ゴム使用 (min_tier=1) → CG_LEMUEN_INTIMATE |
| Memory（INVITATION 消費） | 招待状使用で 1 シーン |

この設計だと **「プレステージ通貨でCGを直接買う」必要がなく**、各 tier で実際にプレイすると自然に解放される。
（直接買い切り型のメタCGアンロックを足すこともできるが、まずは「周回で解放」を主軸にする。）

---

## 2. プレステージ設計

### 2.1 基本ループ

```
通貨を稼ぐ → メタ通貨「源石片」獲得式に従って計算
　　　　  → リセット実行（通貨と強化レベルだけ初期化）
　　　　  → メタショップで永続強化を購入
　　　　  → 次の周回へ
```

### 2.2 リセット時に保持 / 初期化されるもの

| 項目 | プレステージ後 |
|---|---|
| `currency` | **初期化**（0 に） |
| `upgrade_levels` | **初期化** |
| `click_power` / `per_second` | 初期値に戻る（ただしメタ強化分は再付与） |
| `prestige_count` | +1 |
| `prestige_currency`（源石片） | 累積（増える） |
| `meta_upgrade_levels` | **保持** |
| **オペレーター信頼度・ステージ** | **保持** |
| **解放済み CG / Memory / Costume** | **保持** |
| **連投履歴・suspicion・clear状態** | **保持**（基本いじらない） |
| **アクティブ Rule** | **保持** |

→ 「ドクターは記憶を取り戻しつつ、関係性は地続き」の世界観でも筋が通る。

### 2.3 プレステージ通貨の獲得式

仮置き：

```
prestige_currency_gained = floor(sqrt(total_earned_this_run / 1_000_000))
```

| 累計獲得通貨 | 源石片 |
|---|---|
| 1M | 1 |
| 4M | 2 |
| 9M | 3 |
| 100M | 10 |
| 1B | 31 |

序盤は1〜2個、中盤で2桁。バランス調整は実機で。

### 2.4 リセット実行可能条件

- 累計獲得 ≥ 1M（最初）
- 以後ロック無し（いつでもリセット可）

### 2.5 メタ強化（プレステージショップ）

`data/meta_upgrades/*.tres` として持つ。`MetaUpgradeData` を新規定義。

**例:**

| ID | 名前 | 効果 | コスト |
|---|---|---|---|
| `meta_starter_funds` | 初期資金 | 開始時に通貨 +N（レベルで増加） | 1 / 3 / 6 / 10 ... |
| `meta_click_perm_mult` | 永続クリック倍率 | click_power に ×1.05^level | 2 / 5 / 10 ... |
| `meta_per_sec_perm_mult` | 永続自動収益倍率 | per_second に ×1.05^level | 2 / 5 / 10 ... |
| `meta_unlock_doctrine` | ドクトリン強化解放 | Workタブに新カテゴリの強化群が出現 | 5（1回購入） |
| `meta_unlock_originium` | 源石技芸強化解放 | 同上、別カテゴリ | 15（1回購入） |
| `meta_unlock_autoclick` | 自動クリック解放 | クリック自動化、`auto_click_per_sec` 追加 | 30（1回購入） |
| `meta_bond_lemuen` | レミュアンとの絆 | レミュアン専用 reaction tier 解放 | 8（段階) |
| `meta_bond_amiya` | アーミヤとの絆 | 同上 | 8 |
| ... | （オペ別） | ... | ... |

### 2.6 新カテゴリ強化の解放例

**ドクトリン強化**（`meta_unlock_doctrine` 解放後に Workタブに出現）:
- `crit_chance` クリック時に確率で大ヒット
- `combo_window` コンボ持続時間延長
- `streak_bonus` 連続購入で割引

**源石技芸強化**（`meta_unlock_originium` 解放後）:
- `exponential_per_sec` 自動収益が指数的に増加
- `originium_burst` 一定時間ごとに大量入金

`UpgradeData` に `requires_meta: StringName = &""` を追加して、メタ未解放のアップグレードは Workタブに表示しない、という gating で実装。

---

## 3. オペ反応の強化（Tier + 絆）

### 3.1 二軸構成

| 軸 | 進み方 | 反映場所 |
|---|---|---|
| **Tier** | プレステージ回数で全オペ一律に進む（`prestige_count` をそのまま使う） | 全オペの反応バリアント |
| **Bond** | キャラ別にメタショップで購入（`meta_bond_<op_id>`） | そのオペ専用の反応バリアント |

→ 「2周目になると皆ちょっと打ち解けてる」（Tier）＋「課金（プレステージ通貨）でこのキャラとの絆を採掘」（Bond）の二段構え。

### 3.2 データ設計（ReactionRule の拡張）

`scripts/data/reaction_rule.gd` に2つの export を追加:

```gdscript
@export var min_tier: int = 0      # この値以上の reaction_tier が必要
@export var min_bond: int = 0      # この値以上の bond[op_id] が必要
```

`ReactionResolver.resolve()` のフィルタに追加:

```gdscript
if GameState.prestige_count < rule.min_tier:
    continue
if GameState.get_bond(op_id) < rule.min_bond:
    continue
```

`priority` の比較で「より厳しい条件のルールが勝つ」ように、`min_tier + min_bond` を priority に加算するか、resolver 側で tier+bond の合計が高い順に優先するロジックを足す。

### 3.3 GameState 拡張

```gdscript
var prestige_count: int = 0
var prestige_currency: int = 0
var bond: Dictionary = {}                 # StringName -> int
var meta_upgrade_levels: Dictionary = {}  # StringName -> int

func get_bond(op_id: StringName) -> int:
    return bond.get(op_id, 0)
```

### 3.4 反応バリアントの作り方（運用）

ファイル命名規則を拡張:

```
data/reactions/
  xray_caught_lemuen_high.tres            # min_tier=0, min_bond=0
  xray_caught_lemuen_high_t1.tres         # min_tier=1, より親密な台詞
  xray_caught_lemuen_high_t2.tres         # min_tier=2, さらに踏み込み
  xray_caught_lemuen_high_b1.tres         # min_bond=1, 絆ルート専用台詞
  xray_caught_lemuen_high_t1_b1.tres      # 両方満たすときの最上位
```

resolver は **最も多くの条件を満たす最上位のルール**を返す。
新しい台詞を作りたい人は .tres を1個足すだけで済む（コード変更不要）。

#### 具体例：DIRECT_PROT（ゴム）への反応を周回で進化させる

3 つの ReactionRule .tres を用意するだけで「やんわり拒否 → 受け入れ＋CG解放 → 慣れ」の三段が完成する:

| ファイル | min_trust | min_tier | reaction | dialogue | side_effects |
|---|---|---|---|---|---|
| `gift_prot_lemuen.tres` | 60（ステージ3） | 0 | `SHY` | 「まだ早いね、ドクター」 | なし |
| `gift_prot_lemuen_t1.tres` | 60 | 1 | `HAPPY` | 「そんな…でもドクターがどうしてもって言うなら」 | `CG_UNLOCK: cg_lemuen_intimate_first` |
| `gift_prot_lemuen_t2.tres` | 60 | 2 | `DELIGHTED` | 「また？　ふふ、もう手慣れたものね」 | なし |

resolver は priority + tier の両方で勝つ最上位を返すので、prestige_count に応じて自動で正しい反応を選ぶ。
**プレステージ後に同じアイテムを使うだけで「次の段階の関係性」が解放される**ので、ユーザーの自然なインセンティブになる。

### 3.5 Bond レベルが進むと何が変わるか（例）

| Bond Lv | 効果イメージ |
|---|---|
| 0 | 基本反応のみ |
| 1 | ギフト時の trust 増加量 +20%、新セリフが増える |
| 2 | 触れる行動で「親密」分岐の発生率上昇、特定の専用 Memory が見られる |
| 3 | 拘束系・薬品系の拒否反応が緩和、紳士枠コンテンツ全解放 |

具体値は調整しつつ、**Bond は「そのキャラと深く向き合った証」のメタ進行軸** にする。

---

## 4. 実装順序の目安

短いサイクルで価値が出る順:

1. **Shop の DAILY/HOBBY 系を増やす** — 既存仕組みに乗る、データ追加だけ
2. **INVITATION の消費型実装** — ShopService に所持数管理を入れる
3. **ReactionRule に `min_tier` / `min_bond` 追加** — フィールドだけ先に足し、デフォ0で既存挙動維持
4. **GameState に prestige 関連フィールド追加** — 初期値0で既存挙動維持
5. **MetaUpgradeData / メタショップ UI** — 新タブまたは Shop の隠しカテゴリ
6. **プレステージ実行ボタン & 確認ダイアログ** — Workタブ最下部
7. **Tier/Bond 反応バリアントを徐々に量産** — .tres を増やす運用作業

3〜4 までは安全な追加（既存挙動を壊さない）なので会社作業向き。
5 以降は UI 設計と動作確認が必要なので家作業。
