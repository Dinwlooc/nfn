shader_type canvas_item;
//亮度范围：仅当像素亮度在 [threshold_min, threshold_max] 内时参与泛光
uniform float threshold_min : hint_range(0, 1) = 0.6;
uniform float threshold_max : hint_range(0, 1) = 1.0;
// 泛光强度
uniform float intensity : hint_range(0, 2) = 0.5;
// 采样半径
uniform float radius : hint_range(0, 5) = 1.0;
// 是否启用脉冲
uniform bool enable_pulse = false;
uniform float pulse_speed : hint_range(0.1, 5.0) = 2.0;

// 3x3 高斯核
const float kernel[9] = float[](
	0.0625, 0.125, 0.0625,
	0.125,  0.25,  0.125,
	0.0625, 0.125, 0.0625
);

// 判断亮度是否在范围内
bool in_range(float lum) {
	return lum >= threshold_min && lum <= threshold_max;
}

void fragment() {
	vec4 original = texture(TEXTURE, UV) * COLOR;
	float lum = dot(original.rgb, vec3(0.2126, 0.7152, 0.0722));
	
	// 提取范围内的像素（否则置零）
	vec4 highlight = in_range(lum) ? original : vec4(0.0);
	
	// 对范围内像素进行高斯模糊
	vec4 blurred = vec4(0.0);
	for (int i = 0; i < 9; i++) {
		int x = i % 3 - 1;
		int y = i / 3 - 1;
		vec2 offset = vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE * radius;
		vec4 sample_color = texture(TEXTURE, UV + offset) * COLOR;
		float sample_lum = dot(sample_color.rgb, vec3(0.2126, 0.7152, 0.0722));
		// 仅累加在范围内的样本
		if (in_range(sample_lum)) {
			blurred += sample_color * kernel[i];
		}
	}
	
	// 脉冲强度
	float final_intensity = intensity;
	if (enable_pulse) {
		final_intensity *= 0.5 + 0.5 * sin(TIME * pulse_speed);
	}
	vec4 bloom = blurred * final_intensity;
	bloom.a = 0.0;
	COLOR = original + bloom;
}