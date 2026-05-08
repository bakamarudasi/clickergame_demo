class_name CGStep
extends Resource

# CGData.steps の 1 要素。CG ビューアでクリック 1 回ぶんの表示を表す。

# 表示モード。PORTRAIT は立ち絵 + 台詞ボックス、FULL_CG は全画面イラスト + 台詞ボックス。
@export var mode: Enums.CGStepMode = Enums.CGStepMode.PORTRAIT

# FULL_CG モード時に表示する画像。null なら直前の画像を維持する（同じ画像で台詞だけ進む）。
@export var cg_image: Texture2D = null
# 制作者が後で画像を差し込む時の参考用パス（"art/cg/lemuen_intimate_01.png" 等）。
# 表示には使わない。cg_image が null かつここに値が入ってる時はビューアが
# 「(画像未登録: <hint>)」のプレースホルダを出す。
@export var image_path_hint: String = ""

# PORTRAIT モード時の表情キー。OperatorData.portrait_expressions /
# portrait_face_overlays に登録されてるキーを引いて表示する。
@export var expression: StringName = &""

# 話者名の翻訳キー。&"" のときは地の文（モノローグ）として話者欄を非表示にする。
# 例: "OPERATOR_LEMUEN_NAME" / "DOCTOR_NARRATION_NAME"
@export var speaker: String = ""

# 台詞本文の翻訳キー。
@export var dialogue: String = ""

# このステップ表示時に 1 度だけ鳴らす効果音。
@export var sfx: AudioStream = null
