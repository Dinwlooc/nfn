#ifndef SPRITE_FRAME_CROSSFADE_INC
#define SPRITE_FRAME_CROSSFADE_INC

instance uniform bool enable_sprite_crossfade = false;
instance uniform int early_frame = 0;
instance uniform int current_frame = 0;
instance uniform int hframes = 1;
instance uniform int vframes = 1;
instance uniform float sprite_crossfade_amount : hint_range(0, 1) = 1.0;

vec4 blend_crossfade(vec4 early, vec4 curr, float t) {
    float early_weight = early.a * (1.0 - t);
    float curr_weight = curr.a * t;
    float total_weight = early_weight + curr_weight;
    vec4 result;
    if (total_weight > 0.0) {
        result.rgb = (early.rgb * early_weight + curr.rgb * curr_weight) / total_weight;
    } else {
        result.rgb = vec3(0.0);
    }
    result.a = early.a * (1.0 - t) + curr.a * t;
    return result;
}

vec4 apply_sprite_crossfade(sampler2D tex, vec2 uv) {
    if (!enable_sprite_crossfade) {
        return texture(tex, uv);
    }
    float frame_w = 1.0 / float(hframes);
    float frame_h = 1.0 / float(vframes);
    int early_row = early_frame / hframes;
    int early_col = early_frame - early_row * hframes;
    vec2 early_off = vec2(float(early_col) * frame_w, float(early_row) * frame_h);
    int current_row = current_frame / hframes;
    int current_col = current_frame - current_row * hframes;
    vec2 current_off = vec2(float(current_col) * frame_w, float(current_row) * frame_h);
    // 早期帧直接使用当前 UV（因为当前精灵的纹理坐标处于早期帧子区域）
    vec4 early = texture(tex, uv);
    // 目标帧的纹理坐标
    vec2 current_uv = current_off + (uv - early_off);
    vec4 curr = texture(tex, current_uv);
    return blend_crossfade(early, curr, sprite_crossfade_amount);
}
#endif