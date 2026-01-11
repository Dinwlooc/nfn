shader_type canvas_item;

uniform float cooldown_speed = 1.0;
uniform float glow_intensity = 0.30;
uniform float glow_luminance_min = 0.1;
uniform float luminance_max = 1.0;

void fragment() {
    vec4 original_color = texture(TEXTURE, UV);
    vec4 color = original_color;

    // 动态脉动强度
    float pulse = smoothstep(-1, 1, sin(TIME * cooldown_speed));
    float intermittent = pulse * glow_intensity;

    // 邻域偏移
    vec2 offsets[9] = vec2[](
        vec2(-1, -1), vec2(0, -1), vec2(1, -1),
        vec2(-1, 0), vec2(0, 0), vec2(1, 0),
        vec2(-1, 1), vec2(0, 1), vec2(1, 1)
    );

    // 邻域采样
    vec4 glow_color = vec4(0.0);
    vec2 pixel_size = TEXTURE_PIXEL_SIZE * 2.0; // 扩大采样范围增强效果

    for(int i = 0; i < 9; i++) {
        vec2 sample_uv = UV + offsets[i] * pixel_size;
        vec4 sample_color = texture(TEXTURE, sample_uv);
        float sample_luminance = dot(sample_color.rgb, vec3(0.2126, 0.7152, 0.0722));

        if(sample_luminance >= glow_luminance_min) {
            glow_color += sample_color * intermittent * 0.1111; // 1/9
        }
    }

    // 亮度限制
    glow_color.rgb = min(glow_color.rgb, vec3(luminance_max));
    color += glow_color;

    // 最终输出
    COLOR = color;
}