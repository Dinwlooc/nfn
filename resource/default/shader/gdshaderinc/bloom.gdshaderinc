#ifndef BLOOM_INC
#define BLOOM_INC

// ===== 泛光（Bloom）=====
// 全部参数都是 instance uniform，可在编辑器材质面板或 set_instance_shader_parameter 直接手调。
// 光晕由多尺度高斯采样合成：先按亮度软阈值提取高光，再用带微分的采样核扩散；
// 采样点落在 2 个同心环上并逐像素轻微旋转，避免单个像素被复制成规则亮点。

// 总开关。关闭时 apply_bloom 直接返回原色，无采样开销。
instance uniform bool enable_bloom = false;

// 亮度阈值（0–1）。只有亮度高于它的区域参与泛光：0.12 很柔和，0.2–0.35 保留较亮部分，0.5 只留纯亮部。
instance uniform float threshold_min : hint_range(0.0, 1.0) = 0.18;

// 阈值柔化宽度（0–0.5）。阈值附近用 smoothstep 渐入，避免亮暗交界出现硬边和闪点；建议 0.10–0.20。
instance uniform float threshold_softness : hint_range(0.0, 0.5) = 0.16;

// 泛光后亮度上限（0.5–1）。泛光把像素推高到该亮度时平滑收束（不是硬切），1.0 表示基本不限制。
instance uniform float brightness_upper_limit : hint_range(0.5, 1.0) = 0.95;

// 泛光强度（0–2）。0 关闭，0.3–0.8 自然，>1 为强调效果。
instance uniform float bloom_intensity : hint_range(0.0, 2.0) = 0.55;

// 扩散半径（像素）。采样核覆盖的屏幕像素半径，越大光晕越宽；1600×900 背景建议 10–24。
instance uniform float spread : hint_range(0.0, 64.0) = 16.0;

// 采样模糊层级（0–4）。0 最清晰但可能出现颗粒，1–2 平滑，3 更柔；依赖纹理导入时勾选 Mipmaps。
instance uniform float sample_mip : hint_range(0.0, 4.0) = 2.0;

// 采样核逐像素旋转强度（0–1）。打散规则采样条纹，建议 0.3–0.6；0 为固定采样方向。
instance uniform float sample_jitter : hint_range(0.0, 1.0) = 0.4;

// 呼吸开关：让泛光强度按正弦缓慢起伏。
instance uniform bool enable_pulse = false;

// 呼吸幅度（0–1）。0 不变化，0.5 表示强度在 50%–100% 之间起伏。
instance uniform float pulse_depth : hint_range(0.0, 1.0) = 0.5;

// 呼吸速度（0.1–5）。数值越大起伏越快：0.2 约半分钟一轮，2 约 3 秒一轮。
instance uniform float pulse_speed : hint_range(0.1, 5.0) = 1.0;

const vec3 BLOOM_LUMA = vec3(0.2126, 0.7152, 0.0722);
const float BLOOM_TAU = 6.28318530718;
const int BLOOM_INNER_TAPS = 8;
const int BLOOM_OUTER_TAPS = 16;
const float BLOOM_INNER_RATIO = 0.45;

vec3 apply_bloom(sampler2D tex, vec2 uv, vec3 base_color, float time, vec2 texel_size) {
    if (!enable_bloom || bloom_intensity <= 0.0 || spread <= 0.0) return base_color;

    float base_lum = dot(base_color, BLOOM_LUMA);
    float knee = max(threshold_softness, 0.0001);
    vec2 radius = texel_size * spread;

    // 逐像素旋转采样核，避免固定的环状采样在画面里留下规则条纹。
    float noise = fract(sin(dot(uv / max(texel_size, vec2(0.000001)), vec2(12.9898, 78.233))) * 43758.5453);
    float rotation = noise * BLOOM_TAU * sample_jitter;

    float sum_weight = 0.0;
    vec3 sum_color = vec3(0.0);

    // 中心样本保留当前像素附近的真实亮度，权重较低。
    vec4 center_sample = textureLod(tex, uv, 0.0);
    float center_luma = dot(center_sample.rgb, BLOOM_LUMA);
    float center_gate = smoothstep(threshold_min, threshold_min + knee, center_luma);
    float center_weight = 0.6;
    sum_color += center_sample.rgb * center_gate * center_weight;
    sum_weight += center_weight;

    // 内环：8 个样本，半径 0.45R；外环：16 个样本，半径 1.0R；两环角度错开。
    for (int i = 0; i < BLOOM_INNER_TAPS; i++) {
        float angle = rotation + (float(i) + 0.5) * BLOOM_TAU / float(BLOOM_INNER_TAPS);
        vec2 offset = vec2(cos(angle), sin(angle)) * radius * BLOOM_INNER_RATIO;
        vec4 sample_color = textureLod(tex, uv + offset, sample_mip);
        float sample_luma = dot(sample_color.rgb, BLOOM_LUMA);
        float gate = smoothstep(threshold_min, threshold_min + knee, sample_luma);
        float weight = exp(-1.1 * BLOOM_INNER_RATIO * BLOOM_INNER_RATIO);
        sum_color += sample_color.rgb * gate * weight;
        sum_weight += weight;
    }

    for (int i = 0; i < BLOOM_OUTER_TAPS; i++) {
        float angle = rotation + (float(i) + 0.5) * BLOOM_TAU / float(BLOOM_OUTER_TAPS);
        vec2 offset = vec2(cos(angle), sin(angle)) * radius;
        vec4 sample_color = textureLod(tex, uv + offset, sample_mip);
        float sample_luma = dot(sample_color.rgb, BLOOM_LUMA);
        float gate = smoothstep(threshold_min, threshold_min + knee, sample_luma);
        float weight = exp(-1.1);
        sum_color += sample_color.rgb * gate * weight;
        sum_weight += weight;
    }

    float intensity_final = bloom_intensity;
    if (enable_pulse) {
        float wave = 0.5 + 0.5 * sin(time * pulse_speed);
        intensity_final *= mix(1.0 - pulse_depth, 1.0, wave);
    }

    vec3 bloom = (sum_color / max(sum_weight, 0.0001)) * intensity_final;
    float add_luma = dot(bloom, BLOOM_LUMA);
    float room = max(0.0, brightness_upper_limit - base_lum);
    // 平滑天花板：加法在 room 附近渐近收束，避免逐像素硬切换造成亮度断层。
    float allowed = room * add_luma / (add_luma + room + 0.0001);
    float gain = add_luma > 0.0 ? allowed / add_luma : 0.0;

    return base_color + bloom * gain;
}
#endif
