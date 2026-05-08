# 制作するべき画像アセット一覧

> 2026-05-08 時点。現在 Lemuen 1 体ぶん。Texture2D は全て null、`image_path_hint` だけ仕込み済み。
> 1 枚ずつ `preload("res://art/...")` を該当 .tres に書き込めば即座に差し代わる。

---

## 1. 立ち絵（Lemuen 聖衣）

Room タブの大きな立ち絵で使用。`data/costumes/lemuen_default.tres` の各フィールドに紐づく。

| ファイルパス | 用途 | 推奨サイズ | 備考 |
|---|---|---|---|
| `art/portraits/lemuen_default.png` | 通常立ち絵（CostumeData.sprite） | 720×1080 px | 透過 PNG。半身〜膝上 |
| `art/portraits/lemuen_default_pose.png` | 見せつけポーズ（sprite_pose_seductive） | 720×1080 px | 高信頼で xray 気付かれた時。やや崩れた / 挑発的 |
| `art/portraits/lemuen_default_underwear.png` | xray 透視（下着）（sprite_xray_variants） | 720×1080 px | 紳士眼鏡 ON 時 |
| `art/portraits/lemuen_default_nude.png` | xray 透視（裸）（sprite_xray_variants） | 720×1080 px | 高 view_kind |

---

## 2. 表情差分（Lemuen）

`OperatorData.portrait_expressions` または `portrait_face_overlays` に登録。
**ハイブリッド方式**：顔だけ差分が用意できればレイヤー合成（軽い）、無理なら全身差し替え（重い）。

### 推奨：顔差分のみ（小さいテクスチャで OK）

`face_anchor_rect = Rect2(0.3, 0.05, 0.4, 0.3)` の領域に重ねる前提。サイズはその領域に合わせる（≒ 288×324 px）。

| ファイルパス | キー | 用途／場面 |
|---|---|---|
| `art/portraits/lemuen_face_smile.png` | `&"smile"` | 通常の余裕笑み（大半のシーン）|
| `art/portraits/lemuen_face_smug.png` | `&"smug"` | からかい・主導権モード（idle / vibrator T2 等）|
| `art/portraits/lemuen_face_blush.png` | `&"blush"` | 軽く赤面（gift T1 / touch lvl2-3 等）|
| `art/portraits/lemuen_face_shy_smile.png` | `&"shy_smile"` | 照れ笑い（kiss / proposal 系）|
| `art/portraits/lemuen_face_aroused.png` | `&"aroused"` | 蕩けた表情（touch lvl4 / arousal_max / CG 終盤）|
| `art/portraits/lemuen_face_glare.png` | `&"glare"` | 威圧・拒絶（harassment / locked）|
| `art/portraits/lemuen_face_angry.png` | `&"angry"` | 検査拒否（INSP_REJECT）|

### 代替：全身差し替え（素材爆発するけど可）

上記の各表情で `art/portraits/lemuen_full_<expr>.png`（720×1080 px）を作って `portrait_expressions` に登録。
コスチューム × 表情 = 倍数なので、コス増えるなら顔差分推奨。

---

## 3. CG イラスト（HCG ビューア用）

CGViewer の FULL_CG モードで全画面表示。クリック進行で同じ画像内で複数台詞が回るので、**1 枚あたり台詞 2〜4 個ぶんが平均**。

推奨サイズ：**1280×720 px**（ビューポート同サイズ）or **1920×1080 px**（縮小フィット前提）。

### 3-1. CG「初夜」（cg_lemuen_intimate_first / 52 ステップ）

`gift_prot_lemuen_t1.tres` 解放（ゴム 1 個目）

| ファイルパス | 出現ステップ | シーン |
|---|---|---|
| `art/cg/lemuen_intimate_01_intro.png` | 18 | 暗転明け、ベッドの前で抱き上げられた直後 |
| `art/cg/lemuen_intimate_02_lying.png` | 19-20 | ベッドに横たわる、月明かり、太もも内側湿り |
| `art/cg/lemuen_intimate_03_kiss.png` | 21-22 | 唇のキス、舌絡め |
| `art/cg/lemuen_intimate_04_breast.png` | 23-26 | 乳房露出、指で乳首摘み、舌で転がす |
| `art/cg/lemuen_intimate_05_lower.png` | 27-28 | 下着脱がし、秘部露出、月光 |
| `art/cg/lemuen_intimate_06_finger.png` | 29-32 | 中指挿入、クリ + 出し入れ |
| `art/cg/lemuen_intimate_07_finger_deep.png` | 33-34 | 二本指 + Gスポット |
| `art/cg/lemuen_intimate_08_insert.png` | 35-36 | コンドーム装着、挿入直後 |
| `art/cg/lemuen_intimate_09_main.png` | 37-38 | 通常正常位、深く |
| `art/cg/lemuen_intimate_10_fast.png` | 39-42 | 速度UP、激しい腰振り、水音 |
| `art/cg/lemuen_intimate_11_peak.png` | 43-44 | 絶頂瞬間、フラッシュ、痙攣 |
| `art/cg/lemuen_intimate_12_repeat.png` | 45-46 | 連続絶頂、メス堕ち |
| `art/cg/lemuen_intimate_13_climax.png` | 47 | 最後の一突き、限界突破 |

**13 枚**

### 3-2. CG「習慣化」（cg_lemuen_intimate_habit / 25 ステップ）

`gift_prot_lemuen_milestone_100.tres` 解放（ゴム 100 個目）

| ファイルパス | 出現ステップ | シーン |
|---|---|---|
| `art/cg/lemuen_intimate_100_a_room.png` | 9-10 | 私室・部屋着・ソファ。抱き上げられる直前 |
| `art/cg/lemuen_intimate_100_b_bed.png` | 11-21 | ベッドで重なる。私室のラフな雰囲気・髪を下ろした |

**2 枚**（同じベッドシーンを 11 ステップで使い回し）

### 3-3. CG「観察結果」（cg_lemuen_intimate_devote / 32 ステップ）

`gift_prot_lemuen_milestone_500.tres` 解放（ゴム 500 個目）

| ファイルパス | 出現ステップ | シーン |
|---|---|---|
| `art/cg/lemuen_intimate_500_a_dr_sleep.png` | 3-6 | ドクター視点で覗き込むレミュアン（執務机の上から） |
| `art/cg/lemuen_intimate_500_b_pushed.png` | 7-8 | 私室のベッドに押し倒され、彼女が服のボタンを外す |
| `art/cg/lemuen_intimate_500_c_mount.png` | 9-11 | 馬乗り、秘部を擦りつける |
| `art/cg/lemuen_intimate_500_d_condom.png` | 12-15 | 自分でゴム着け、焦らし指使い |
| `art/cg/lemuen_intimate_500_e_riding.png` | 16-28 | 騎乗位、主導権彼女、両手押さえつけ→絶頂 |

**5 枚**

### 3-4. CG「誓約」（cg_lemuen_intimate_break / 28 ステップ）

`gift_prot_lemuen_milestone_1000.tres` 解放（ゴム 1000 個目）

| ファイルパス | 出現ステップ | シーン |
|---|---|---|
| `art/cg/lemuen_intimate_1000_a_morning.png` | 2 | 朝の光、抱き合ったままベッドで目覚め |
| `art/cg/lemuen_intimate_1000_b_bracelet.png` | 3-7 | チタンブレスレットが朝日に光るアップ |
| `art/cg/lemuen_intimate_1000_c_kiss.png` | 8 | 起き抜けに覆い被さってキス |
| `art/cg/lemuen_intimate_1000_d_intense.png` | 9-13 | 激しい腰振り、必死さ、朝の光 |
| `art/cg/lemuen_intimate_1000_e_tears.png` | 14-21 | 涙混じり、絶頂、抱き合いシンクロ |
| `art/cg/lemuen_intimate_1000_f_heartbeat.png` | 22-27 | 事後・指で胸の心音を聴く・誓約 |

**6 枚**

### CG 合計：26 枚

---

## 4. アイテムアイコン（任意・後回し OK）

`ItemData.icon` フィールド用。Shop タブとインベントリで小さく表示。
推奨サイズ：**128×128 px**

| ファイルパス | アイテム |
|---|---|
| `art/items/medical_protector.png` | ゴム |
| `art/items/closure_vibrator.png` | 振動デバイス |
| `art/items/originium_relief_oil.png` | オイル |
| `art/items/originium_rope.png` | ロープ |
| `art/items/warfarin_pink_gas.png` | 媚薬 |
| `art/items/kashmir_novel.png` | 騎士小説 |
| `art/items/titanium_bracelet.png` | チタンブレス |
| `art/items/feline_catears.png` | 猫耳 |
| `art/items/gift_tea_premium.png` | 高級紅茶 |
| `art/items/gift_cookie.png` | クッキー |
| `art/items/gift_coffee.png` | コーヒー |
| `art/items/gift_sandwich.png` | サンドイッチ |
| `art/items/gift_energy_drink.png` | エナドリ |
| `art/items/gift_bento.png` | 弁当 |
| `art/items/gift_chocolate.png` | チョコ |
| `art/items/blend_tea.png` | ブレンドティー |
| `art/items/midnight_examination.png` | 深夜検査チケット |
| `art/items/coral_coast_swimsuit.png` | 水着 |
| `art/items/prts_visor.png` | 紳士眼鏡 |
| `art/items/scope_basic_item.png` | スコープアイテム |
| `art/items/scope_battery.png` | スコープ電池 |
| `art/items/rule_underwear_mandate.png` | 下着規定 |

**~22 枚**（任意）

---

## 5. UI / システム素材（既に揃ってるはず）

| ファイル | 状態 |
|---|---|
| `assets/paperwork.svg` | ✅ 既存（Work タブ書類アイコン）|
| `icon.svg` | ✅ 既存（プロジェクトアイコン）|

---

## 6. BGM / SFX（任意・空スロットあり）

`CGData.bgm` と `CGStep.sfx` に AudioStream スロットあり。null 許容。

候補（必要なら）：
- `audio/bgm/intimate_first.ogg` — 初夜 BGM（ピアノ系・控えめ）
- `audio/bgm/intimate_break.ogg` — 誓約 BGM（弦楽・感情的）
- `audio/sfx/heartbeat.wav` — 心音（CG_BREAK 22-23 で使える）
- `audio/sfx/gunshot.wav` — idle "fire" の銃声
- `audio/sfx/wet_kiss.wav` — キス系
- `audio/sfx/click.wav` — Work クリック音

---

## 優先順位サマリ

| 優先度 | 内容 | 体験へのインパクト |
|---|---|---|
| 🔥 1 | Lemuen 通常立ち絵（lemuen_default.png）| Room タブが空白から脱出 |
| 🔥 2 | 表情差分 7 種（顔差分方式）| 反応の感情変化が可視化 |
| ⭐ 3 | CG「初夜」13 枚 | 1 個目のゴム解放で初イベント完成 |
| ⭐ 4 | CG「習慣化」2 枚 | 100 マイルストーン |
| 🌿 5 | CG「観察結果」5 枚 | 500 マイルストーン |
| 🌿 6 | CG「誓約」6 枚 | 1000 マイルストーン（最終）|
| 🌿 7 | xray 用バリアント 2 枚 | 紳士眼鏡演出補完 |
| 任意 | アイテムアイコン 22 枚 | UX 向上だがゲーム進行に必須でない |
| 任意 | BGM / SFX | 没入感補強 |

---

## 描き直しの楽さ

全画像 null 許容で、`image_path_hint` の文字列パスを参照しながら **PNG 1 枚作って同名で配置 → .tres の `cg_image = preload("res://art/cg/<filename>")` を 1 行追加**だけ。シナリオ・台詞・進行ロジックは全て確定済みなので、画像作成と並行して他作業（新キャラ追加など）は止めずに進められる。
