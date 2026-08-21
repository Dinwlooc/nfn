#ifndef BLOOM_INC
#define BLOOM_INC

instance uniform bool enable_bloom = false;
instance uniform float threshold_min : hint_range(0, 1) = 0.6;
instance uniform float brightness_upper_limit : hint_range(0, 1) = 1.0;
instance uniform float bloom_intensity : hint_range(0, 2) = 0.5;
instance uniform float spread : hint_range(0, 5) = 1.0;
instance uniform bool enable_pulse = false;
instance uniform float pulse_speed : hint_range(0.1, 5.0) = 2.0;

vec3 apply_bloom(sampler2D tex, vec2 uv, vec3 base_color, float time, vec2 texel_size) {
    if (!enable_bloom) return base_color;

    float base_lum = dot(base_color, vec3(0.2126, 0.7152, 0.0722));
    vec3 sum_color = vec3(0.0);
    float sum_luma = 0.0;

    for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
            if (dx == 0 && dy == 0) continue;
            float weight = (abs(dx) == 1 && abs(dy) == 1) ? 0.70710678 : 1.0;
            vec2 offset = vec2(float(dx), float(dy)) * texel_size * spread;
            vec4 sample = texture(tex, uv + offset);
            float sample_lum = dot(sample.rgb, vec3(0.2126, 0.7152, 0.0722));
            if (sample_lum > threshold_min) {
                sum_color += sample.rgb * weight;
                sum_luma += sample_lum * weight;
            }
        }
    }

    float intensity_final = bloom_intensity;
    if (enable_pulse) {
        intensity_final *= 0.5 + 0.5 * sin(time * pulse_speed);
    }

    vec3 bloom = vec3(0.0);
    if (sum_luma > 0.0 && intensity_final > 0.0) {
        float raw_increment = sum_luma * intensity_final;
        float max_increment = max(0.0, brightness_upper_limit - base_lum);
        float scale = min(1.0, max_increment / raw_increment);
        bloom = sum_color * intensity_final * scale;
    }
    return base_color + bloom;
}
#endif