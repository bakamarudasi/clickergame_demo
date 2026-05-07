# アセット命名規則・作業仕様

立ち絵などのアセット作成時の命名・配置ルール。これに従っておけば `.tres` の path 指定を変えずにファイル差し替えだけで済む。

---

## 1. ディレクトリ構造（オペレータ立ち絵）

```
assets/operators/<op_id>/
├─ <costume_id>/
│  ├─ normal.png              ← 必須：通常立ち絵
│  ├─ pose_seductive.png      ← 高信頼でX線バレ時の見せつけ
│  ├─ xray_<view_kind>.png    ← 紳士眼鏡ON時の透過版（複数可）
│  └─ portrait_idle.png       ← 任意：Roomで normal と別の立ち絵を使いたい場合
└─ expressions/               ← 任意：表情差分（顔だけでOK）
   ├─ blush.png
   ├─ angry.png
   ├─ smile.png
   └─ surprise.png
```

### 必須ファイル

衣装1着につき：

| ファイル | 用途 | 無いと困る場面 |
|---|---|---|
| `normal.png` | 通常立ち絵 | Room常時表示 |
| `xray_underwear.png` | 標準スコープ用透過版 | 👓 紳士眼鏡ON |
| `pose_seductive.png` | 見せつけポーズ | X線高信頼バレ時 |

### 任意ファイル

| ファイル | 用途 |
|---|---|
| `xray_nude.png` | 上位スコープ（完全透過） |
| `xray_thermal.png` | 熱画像スコープ |
| `xray_swimsuit.png` | 水着差分スコープ |
| `expressions/<key>.png` | `OperatorData.portrait_expressions` 用、`ReactionRule.expression` で参照 |

---

## 2. 命名規則の原則

### 識別子（IDとフォルダ名）

| 種類 | 例 | 規則 |
|---|---|---|
| `<op_id>` | `lemuen` `nian` `blaze` | snake_case、英数字とアンダースコアのみ |
| `<costume_id>` | `default` `maid` `swimsuit` `casual` | 〃 |
| `<view_kind>` | `underwear` `nude` `thermal` `mood` | 〃。ScopeData.view_kind と一致させる |
| `<expression_key>` | `blush` `angry` `smile` `surprise` | 〃。ReactionRule.expression と一致させる |

### ファイル名のテンプレ

```
assets/operators/<op_id>/<costume_id>/<variant>.<ext>

variant ∈ {normal, pose_seductive, xray_<view_kind>, portrait_idle}
```

### 言語表記

ファイル名・フォルダ名は**英語snake_case 固定**。日本語は `translations/strings.csv` で管理。

---

## 3. アセット仕様

| 項目 | 値 |
|---|---|
| 推奨解像度 | **720×960 〜 1080×1440**（縦長 3:4） |
| 最低解像度 | 280×380（Room表示の最小値）|
| フォーマット | **PNG（透過あり）推奨**。SVG も可（小サイズ・ベクタ） |
| 表示挙動 | `KEEP_ASPECT_CENTERED` で領域に収まる。元画像が大きくてOK |
| 背景 | 透過 or 単色。立ち絵は **キャラだけ** が良い（背景は別管理）|

### アスペクト比の合わせ方

ノーマル / xray / pose は**同じ構図・同じアスペクト**で揃える。違うとON/OFF切替時に立ち絵が動いて違和感出る。

ComfyUI ワークフロー推奨：
- 同一プロンプトベース＋**ControlNet（pose / depth）固定**
- 服／下着／ポーズだけ差し替えるバッチ
- 出力サイズ統一

---

## 4. ファイル差し替え手順（プレースホルダ→本物）

1. 既存の `.svg` ファイルを **同じファイル名** で `.png` に置き換える場合（推奨）：
   1. `<costume_id>/normal.svg` を削除（or 残しても良い）
   2. `<costume_id>/normal.png` を配置
   3. Godot で開く → 自動的に `normal.png.import` が生成される
   4. **`.tres` の `ext_resource path` の拡張子を `.svg` → `.png` に書き換え**
   5. UID は新しく生成されるので `uid://` の値も更新が必要

2. 同じ `.svg` のままアートを差し替える場合：
   1. SVG ファイルを上書き保存
   2. Godot で再インポートされるだけ。**`.tres` 修正不要**

> 拡張子変更が面倒な場合は SVG のまま運用してもOK。Godot は SVG をベクタとして高品質に扱える。

---

## 5. 新キャラ追加の作業フロー

例：ニェンを追加する場合

```
1. assets/operators/nian/ フォルダ作成
2. assets/operators/nian/default/ サブフォルダ作成
3. 以下の3枚を配置：
   - normal.png
   - xray_underwear.png
   - pose_seductive.png
4. data/operators/nian.tres を作成（lemuen.tres を雛形にコピー）
   - id = &"nian"
   - personality = 1 (ANCIENT_FREE)
   - portrait_idle = res://assets/operators/nian/default/normal.svg
   - xray_detection_rate = 0.6 (鈍い)
   - default_costume_id = &"nian_default"
   - unlock_cost = 5000 (招待状ゲート)
5. data/costumes/nian_default.tres を作成
6. data/reactions/<reaction>_nian_*.tres を作成（最低でも検査・X線の各trust帯）
7. translations/strings.csv に名前・台詞のキー追加
```

→ コード変更ゼロ。データのみで完結。

---

## 6. 新衣装追加の作業フロー

例：レミュアンにメイド服を追加する場合

```
1. assets/operators/lemuen/maid/ フォルダ作成
2. 以下を配置：
   - normal.png
   - xray_underwear.png
   - pose_seductive.png
3. data/costumes/lemuen_maid.tres を作成
   - id = &"lemuen_maid"
   - operator_id = &"lemuen"
   - sprite, sprite_xray_variants, sprite_pose_seductive を新画像に
   - shop_price = 3000 etc
4. （ショップ販売なら）data/items/costume_lemuen_maid.tres を作成
   - effects に COSTUME_UNLOCK target = &"lemuen_maid"
5. translations/strings.csv に COSTUME_LEMUEN_MAID 追加
```

---

## 7. 新スコープ（透視タイプ）追加の作業フロー

例：熱画像スコープを追加する場合

```
1. 各 CostumeData の sprite_xray_variants に新キーで画像追加
   - lemuen/default/xray_thermal.png 配置
   - lemuen_default.tres の sprite_xray_variants に
       &"thermal": ExtResource("...thermal画像")
     を追加
2. data/scopes/scope_thermal.tres を作成
   - view_kind = &"thermal"
   - suspicion_rate = 0.3 （バレにくい）
3. data/items/scope_thermal_item.tres を作成
   - effects に SCOPE_GRANT target = &"scope_thermal"
4. translations/strings.csv に SCOPE_THERMAL_NAME / DESC 追加
```

---

## 8. アセットチェックリスト

### 最低限版（1キャラ動作確認）

- [ ] `assets/operators/lemuen/default/normal.png`
- [ ] `assets/operators/lemuen/default/xray_underwear.png`
- [ ] `assets/operators/lemuen/default/pose_seductive.png`

### 標準版（3キャラ揃い）

レミュアン・ニェン・ブレイズの各 `default/` に上記3枚 = **計9枚**

### 充実版（衣装＋表情）

- 各キャラ追加衣装1着 = **+9枚**
- 表情差分 4種（blush/angry/smile/surprise）= **+12枚**

---

## 9. プレースホルダ運用

`assets/operators/lemuen/default/*.svg` は**プレースホルダSVG**として配置済。本番アセットができ次第差し替え可能。

UI上で簡単に判別できるよう、以下のテキスト入りで作ってある：
- `LEMUEN [NORMAL]` / `[XRAY]` / `[POSE]`

---

## 10. クイック参照：コードとアセットの紐付け

| Resource フィールド | アセット参照 |
|---|---|
| `OperatorData.portrait_idle` | `assets/operators/<op>/<costume>/normal.svg` |
| `CostumeData.sprite` | `assets/operators/<op>/<costume>/normal.svg` |
| `CostumeData.sprite_pose_seductive` | `assets/operators/<op>/<costume>/pose_seductive.svg` |
| `CostumeData.sprite_xray_variants[&"underwear"]` | `assets/operators/<op>/<costume>/xray_underwear.svg` |
| `CostumeData.sprite_xray_variants[&"<kind>"]` | `assets/operators/<op>/<costume>/xray_<kind>.svg` |
| `OperatorData.portrait_expressions[&"blush"]` | `assets/operators/<op>/expressions/blush.svg` |
