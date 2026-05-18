# Audio Asset Download List

このファイルは「家帰って Windows 版 Claude Code に渡して一括 DL させる」ための
**買い物リスト兼指示書**。各セクション末尾の手順をそのまま Claude Code に投げれば
DL → リネーム → コミットまで一気にやらせられる構成にしてある。

---

## 0. 大原則

- **形式**: 最終的に **`.ogg`** に揃える（Godot 4.6 の推奨形式、ループタグ埋込可、ストリーミング軽量）。
  - DL したのが `.mp3` / `.wav` でも構わない。ffmpeg で変換する：
    ```bash
    ffmpeg -i input.mp3 -codec:a libvorbis -qscale:a 5 output.ogg
    ```
- **配置場所**: `assets/audio/bgm/<slot>.ogg` / `assets/audio/sfx/<name>.ogg`
- **slot 名**は `scripts/autoload/bgm_service.gd` の `_tracks` 辞書キーと一致させる
  （`work` / `room` / `shop` / `meta` / `prestige` / `xray_caught`）。
- **DL 後の登録**: `scripts/main.gd` の `_ready` 末尾に以下を追記すれば即鳴る：
  ```gdscript
  BGMService.set_track_stream(&"work", preload("res://assets/audio/bgm/work.ogg"))
  BGMService.set_track_stream(&"room", preload("res://assets/audio/bgm/room.ogg"))
  BGMService.set_track_stream(&"shop", preload("res://assets/audio/bgm/shop.ogg"))
  BGMService.set_track_stream(&"meta", preload("res://assets/audio/bgm/meta.ogg"))
  BGMService.set_track_stream(&"prestige", preload("res://assets/audio/bgm/prestige.ogg"))
  ```
- **CC0 を最優先**で選ぶ（クレジット表記不要 = 後で揉めない）。
- DL したら **必ず `CREDITS.md` を更新**（作者・サイト名・ライセンス・URL）。

---

## 1. BGM（タブ・シーン別）

### 1-A. `work.ogg` — Work タブ（クリック作業中・低主張・ループ）

長時間流す前提。**主張弱め・テンポゆるめ・繰り返し聴いて疲れない**もの。

| 優先 | サイト | 直リン候補 | 形式 | ライセンス |
|---|---|---|---|---|
| ★ | Tallbeard Studios | https://tallbeard.itch.io/music-loop-bundle | wav/ogg | **CC0** |
| ★ | 甘茶の音楽工房 | https://amachamusic.chagasi.com/genre/dentsi.html | mp3 | クレジット任意（書く方が無難） |
| ☆ | BGMer | https://bgmer.net/ | mp3 | クレジット表記必要 |
| ☆ | OpenGameArt CC0 | https://opengameart.org/content/cc0-music-0 | ogg/wav | **CC0** |

**選曲ヒント**: テンポ 80-110 BPM、minimal techno / ambient / lo-fi 系。

### 1-B. `room.ogg` — Room タブ（観測・緊張感・サイバー）

ゲームの中核タブ。**ダーク寄り・電子音・ドローン**。観測室の空気を演出。

| 優先 | サイト | 直リン候補 | 形式 | ライセンス |
|---|---|---|---|---|
| ★ | 魔王魂・サイバー | https://maou.audio/category/bgm/bgm-cyber/ | ogg/mp3 | クレジット表記必要 |
| ★ | Soundimage.org | https://soundimage.org/looping-music/ | mp3 | CC BY 4.0（クレジット必要） |
| ★ | PixelLoops Sci-Fi | https://pixelloops.itch.io/sci-fi-ambient-music-pack-20-loopable-tracks-for-games | wav/ogg | 有料（買うなら最強） |
| ☆ | OpenGameArt "ambient" tag | https://opengameart.org/art-search-advanced?keys=cyber+ambient&type%5B%5D=Music | 各種 | CC0/CC BY |

**選曲ヒント**: "Cyber Dream Loop" (Soundimage)、魔王魂の「機械文明」「電脳世界」系。

### 1-C. `shop.ogg` — Shop タブ（軽快・商業・短尺ループ）

物資調達画面。**明るめ・軽快・テンポ良い**もの。

| 優先 | サイト | 直リン候補 | 形式 | ライセンス |
|---|---|---|---|---|
| ★ | 甘茶の音楽工房・ジャズ/ボサ | https://amachamusic.chagasi.com/genre/jazz.html | mp3 | クレジット任意 |
| ★ | BGMer | https://bgmer.net/ | mp3 | クレジット表記必要 |
| ☆ | Tallbeard Studios | https://tallbeard.itch.io/music-loop-bundle | wav/ogg | **CC0** |

**選曲ヒント**: ローファイ / ライトジャズ / シンセウェーブ。

### 1-D. `meta.ogg` — Meta タブ（厳粛・覚醒・少し荘厳）

プレステージ後の世界。**スペーシー・浮遊感・神秘的**。

| 優先 | サイト | 直リン候補 | 形式 | ライセンス |
|---|---|---|---|---|
| ★ | OtoLogic アンビエント | https://otologic.jp/free/bgm/ambient01.html | mp3/wav | クレジット表記必要 |
| ★ | Soundimage Ethereal | https://soundimage.org/fantasywonder/ | mp3 | CC BY 4.0 |
| ☆ | Tallbeard | https://tallbeard.itch.io/music-loop-bundle | wav/ogg | **CC0** |

**選曲ヒント**: ピアノ + パッド、長め残響、ゆったり 60-80 BPM。

### 1-E. `prestige.ogg` — プレステージ実行時（短尺・覚醒・1度限り）

実行ボタン押した瞬間に流す **30秒〜1分のジングル**。ループ不要。

| 優先 | サイト | 直リン候補 | 形式 | ライセンス |
|---|---|---|---|---|
| ★ | Zapsplat "transcend"/"awakening" | https://www.zapsplat.com/sound-effect-category/musical-stings-and-idents/ | mp3/wav | 要無料登録 |
| ☆ | Freesound.org | https://freesound.org/search/?q=transcendence | 各種 | CC0/CC BY |

---

## 2. SFX（短尺効果音）

`assets/audio/sfx/<name>.ogg` で配置。1秒以下なら `.wav` でも可（むしろ即時再生で有利）。

| ファイル名 | 用途 | 探し方 | 推奨サイト |
|---|---|---|---|
| `click.ogg` | Work タブのクリック | "ui click subtle" | Zapsplat / Freesound |
| `purchase.ogg` | Shop 購入成功 | "purchase confirm" | Zapsplat |
| `unlock.ogg` | CG/衣装解禁 | "unlock chime" | Freesound |
| `xray_caught.ogg` | 観測バレ | "alarm short" | Freesound |
| `stage_advance.ogg` | 信頼度ステージアップ | "level up bright" | Zapsplat |
| `toast_notice.ogg` | トースト通知 | "ui notification subtle" | Freesound |
| `toast_warn.ogg` | 警戒トースト | "ui warning blip" | Freesound |
| `tab_switch.ogg` | タブ切替 | "ui swoosh short" | Freesound |

**配信元一括**:
- Freesound: https://freesound.org/search/?q=ui (要無料登録、CC0 フィルタ可)
- Zapsplat: https://www.zapsplat.com/sound-effect-category/user-interface/ (要無料登録)
- Kenney UI Audio: https://kenney.nl/assets/ui-audio (**CC0**、UI 用パック一括)

**最強の一括 DL**: [Kenney UI Audio パック](https://kenney.nl/assets/ui-audio) は CC0 で 50+ UI 音入り。
ZIP 1個落としてリネームすれば SFX 棚全部埋まる。

---

## 3. Windows 版 Claude Code への指示テンプレ

家帰ったらこれを Windows 側にコピペして投げる：

```
以下を順に実行：

1. 以下のサイトから音源を DL する：
   - Tallbeard CC0 Music Loop Bundle: https://tallbeard.itch.io/music-loop-bundle
   - Kenney UI Audio (CC0): https://kenney.nl/assets/ui-audio
   - 魔王魂サイバーから 1曲: https://maou.audio/category/bgm/bgm-cyber/
   - Soundimage Cyber Dream Loop: https://soundimage.org/looping-music/

2. DL したファイルから以下のスロットを埋める：
   - assets/audio/bgm/work.ogg   ← Tallbeard から minimal/lofi 系
   - assets/audio/bgm/room.ogg   ← 魔王魂 or Soundimage のサイバー系
   - assets/audio/bgm/shop.ogg   ← Tallbeard から明るめ
   - assets/audio/bgm/meta.ogg   ← Tallbeard から ambient/ethereal
   - assets/audio/bgm/prestige.ogg ← 短尺ジングル
   - assets/audio/sfx/*.ogg      ← Kenney UI Audio から各 UI 音をリネーム

3. .mp3/.wav は ffmpeg で .ogg に変換：
   ffmpeg -i input.mp3 -codec:a libvorbis -qscale:a 5 output.ogg

4. assets/audio/CREDITS.md を実際の選曲内容で更新する
   （作者・サイト名・ライセンス・URL を必ず書く）

5. scripts/main.gd の _ready 末尾に以下を追記：
   BGMService.set_track_stream(&"work", preload("res://assets/audio/bgm/work.ogg"))
   BGMService.set_track_stream(&"room", preload("res://assets/audio/bgm/room.ogg"))
   BGMService.set_track_stream(&"shop", preload("res://assets/audio/bgm/shop.ogg"))
   BGMService.set_track_stream(&"meta", preload("res://assets/audio/bgm/meta.ogg"))
   BGMService.set_track_stream(&"prestige", preload("res://assets/audio/bgm/prestige.ogg"))

6. Godot で開いて F5 で起動確認。タブ切替で BGM クロスフェードするはず。
   ⚙ ボタンから音量調整できることも確認。

7. コミット & プッシュ。コミットメッセージは：
   audio: drop in BGM tracks + SFX, register in main
```

---

## 4. ライセンス早見表

| ライセンス | クレジット必要 | 改変可 | 商用可 | 備考 |
|---|---|---|---|---|
| **CC0** / Public Domain | × | ◎ | ◎ | **最強**。気にせず使える |
| **CC BY 4.0** | ◎ 必須 | ◎ | ◎ | 作者名 + ライセンス名を表記 |
| **CC BY-SA** | ◎ 必須 | ◎ | ◎ | 派生物も同じライセンスにする義務あり（避ける） |
| **CC BY-NC** | ◎ 必須 | ◎ | **×** | 非商用のみ。商用ゲームには使えない |
| サイト独自規約 | 通常 必要 | △ | ○ | 個別に規約読む（魔王魂・BGMer 等） |

→ **NC が付いてる曲は絶対に使わない**。CC BY と CC0 のみが安全。

---

## 5. 困ったら

- 音源未差し込みでも **BGMService が無音停止に倒すのでクラッシュしない**。
  → 1〜2曲だけ仮で入れて他は空でも動作確認可能。
- ループの繋ぎが汚い場合は Audacity でクロスフェード処理：
  曲尾 0.5秒 と 曲頭 0.5秒 を選択して `Effect > Fade In/Out`。
- 容量が気になるなら `qscale:a 4`（より圧縮）で .ogg 化（音質と引き換え）。
