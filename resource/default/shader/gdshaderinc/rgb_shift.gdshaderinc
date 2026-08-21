#ifndef RGB_SHIFT_INC
#define RGB_SHIFT_INC

instance uniform float distortion_intensity : hint_range(0, 3) = 0.0;

vec4 apply_rgb_shift(sampler2D tex, vec2 uv, float intensity, vec2 texel_size) {
    if (intensity == 0.0) {
        return texture(tex, uv);
    }
    float r = texture(tex, uv + intensity * texel_size).r;
    float g = texture(tex, uv).g;
    float b = texture(tex, uv - intensity * texel_size).b;
    float a = texture(tex, uv).a;
    return vec4(r, g, b, a);
}
#endif