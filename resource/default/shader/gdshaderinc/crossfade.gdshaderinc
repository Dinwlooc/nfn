#ifndef CROSSFADE_INC
#define CROSSFADE_INC

uniform sampler2D early_texture;  // 纹理不能声明为 instance uniform
instance uniform bool enable_crossfade = false;
instance uniform float crossfade_amount : hint_range(0, 1) = 1.0;

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

vec4 apply_crossfade(sampler2D tex, vec2 uv, vec4 base) {
    if (enable_crossfade) {
        vec4 early = texture(early_texture, uv);
        return blend_crossfade(early, base, crossfade_amount);
    }
    if (enable_sprite_crossfade) {
        float frame_w = 1.0 / float(hframes);
        float frame_h = 1.0 / float(vframes);
        int early_row = early_frame / hframes;
        int early_col = early_frame - early_row * hframes;
        vec2 early_off = vec2(float(early_col) * frame_w, float(early_row) * frame_h);
        int current_row = current_frame / hframes;
        int current_col = current_frame - current_row * hframes;
        vec2 current_off = vec2(float(current_col) * frame_w, float(current_row) * frame_h);
        vec4 early = texture(tex, uv);
        vec2 current_uv = current_off + (uv - early_off);
        vec4 curr = texture(tex, current_uv);
        return blend_crossfade(early, curr, sprite_crossfade_amount);
    }
    return base;
}
#endif