shader_type canvas_item;

uniform vec4 flash_color : source_color;
uniform float flash_intensity : hint_range(0, 1) = 0.0;
uniform float alpha : hint_range(0, 1) = 1.0;
uniform bool enable_crossfade = false;
uniform sampler2D early_texture;
uniform float crossfade_amount : hint_range(0, 1) = 1.0;

uniform bool enable_sprite_crossfade = false;
uniform int early_frame = 0;
uniform int current_frame = 0;
uniform int hframes = 1;
uniform int vframes = 1;
uniform float sprite_crossfade_amount : hint_range(0, 1) = 1.0;

// 混合函数：按alpha权重混合两个颜色
vec4 blend_crossfade(vec4 early, vec4 curr, float t) {
    float early_weight = early.a * (1.0 - t);
    float curr_weight = curr.a * t;
    float total_weight = early_weight + curr_weight;
    vec4 result;
    if (total_weight > 0.0) {
        result.rgb = (early.rgb * early_weight + curr.rgb * curr_weight) / total_weight;
    } else {
        result.rgb = vec3(0.0); // 两者完全透明，颜色无关紧要
    }
    result.a = early.a * (1.0 - t) + curr.a * t;
    return result;
}
void fragment() {
    vec4 current = texture(TEXTURE, UV);
    vec4 base = current;
    if (enable_crossfade) {
        vec4 early = texture(early_texture, UV);
        base = blend_crossfade(early, current, crossfade_amount);
    }
    else if (enable_sprite_crossfade) {
        float frame_w = 1.0 / float(hframes);
        float frame_h = 1.0 / float(vframes);
        int early_row = early_frame / hframes;
        int early_col = early_frame - early_row * hframes;
        vec2 early_off = vec2(float(early_col) * frame_w, float(early_row) * frame_h);
        int current_row = current_frame / hframes;
        int current_col = current_frame - current_row * hframes;
        vec2 current_off = vec2(float(current_col) * frame_w, float(current_row) * frame_h);
        vec4 early = texture(TEXTURE, UV);
        vec2 current_uv = current_off + (UV - early_off);
        vec4 curr = texture(TEXTURE, current_uv);
        base = blend_crossfade(early, curr, sprite_crossfade_amount);
    }
    vec3 mixed_rgb = mix(base.rgb, flash_color.rgb, flash_intensity);
    COLOR = vec4(mixed_rgb, base.a * alpha);
}