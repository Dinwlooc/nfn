shader_type canvas_item;

// 闪烁颜色，可在编辑器中选取或通过代码设置
uniform vec4 flash_color : source_color;
// 闪烁强度，范围 0~1，0 为完全原始颜色，1 为完全目标颜色
uniform float flash_intensity : hint_range(0, 1) = 0.0;

void fragment() {
	// 原始颜色 = 纹理颜色 × 顶点/调制颜色
	vec4 original = texture(TEXTURE, UV) * COLOR;
	// 混合 RGB，保留原始透明度
	vec3 mixed_rgb = mix(original.rgb, flash_color.rgb, flash_intensity);
	COLOR = vec4(mixed_rgb, original.a);
}