shader_type canvas_item;

// 観測モニタ風の横スキャンライン。Room タブの最前面に薄く重ねる前提。
// FRAGCOORD ベースなので拡縮の影響を受けない。線の密度・厚みは uniform で調整可。

uniform vec4 line_color : source_color = vec4(0.365, 0.812, 0.969, 0.06);
uniform float line_spacing : hint_range(2.0, 16.0) = 3.0;
uniform float line_thickness : hint_range(0.1, 4.0) = 1.0;
uniform float scroll_speed : hint_range(-200.0, 200.0) = 18.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	// 横スキャンライン
	float y = FRAGCOORD.y;
	float pattern = mod(y + TIME * scroll_speed, line_spacing);
	float on = step(line_spacing - line_thickness, pattern);
	vec4 scan = line_color * on;

	// 軽い周辺暗化。UV を中心からの距離で測る。
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered) * 1.4;          // 1.0 で 70% 強くらい
	float vig = smoothstep(0.5, 1.0, dist) * vignette_strength;
	vec4 vignette = vignette_color * vig;

	COLOR = scan + vignette;
}
