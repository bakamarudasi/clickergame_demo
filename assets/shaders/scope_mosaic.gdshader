shader_type canvas_item;

// 紳士枠の「低画質」表現。block_size [px] にしたがって UV をテクセル単位で
// 量子化し、ブロック中央の色をブロック全体に塗る＝モザイク化。
// 1.0 で素通し（劣化なし）、24.0 でガビガビ。room_tab 側が
// ScopeData.resolution_level からこの値を計算して uniform に流す。

uniform float block_size : hint_range(1.0, 64.0) = 1.0;

void fragment() {
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 px = UV * tex_size;
	vec2 snapped_px = (floor(px / block_size) + 0.5) * block_size;
	COLOR = texture(TEXTURE, snapped_px / tex_size);
}
