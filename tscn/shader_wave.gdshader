shader_type canvas_item;

uniform sampler2D input_texture;
uniform float row_density = 0.1; // 选中概率（0-1）
uniform float wave_length = 0.1; // 采样波长（UV空间）
uniform float max_offset = 0.1; // 波强
uniform bool execute_effect = true;
uniform float random_seed = 0;//0~1之间的五位小数
uniform int wave_mode = 1;//
// 优化后的浮点哈希函数
float hash(float v, float seed) {
float n = fract(dot(vec2(v, seed), vec2(0.5671, 0.1234)) * 100.0);
return n;
}

void fragment() {
vec2 uv = UV;//UV的范围是(0,0)~(1,1)
if(execute_effect) {
// 空间参数预计算
float search_radius = wave_length * 0.5;
float min_dist = search_radius;
float closest_v = -1.0;

// 8*2采样算法
int MAX_SAMPLES = 8*wave_mode;
float _step = search_radius / float(MAX_SAMPLES);
float search_v = floor(uv.y / _step);//合并采样行单元,映射为采样行坐标系
for(int i = 0; i <= MAX_SAMPLES; i++) {
	float sample_v = search_v + float(i);
	if(hash(sample_v*_step, random_seed) >= row_density){
		sample_v = search_v - float(i);
		if(hash(sample_v*_step, random_seed) >= row_density) continue;
		}
	min_dist = abs(uv.y - sample_v*_step);
	closest_v = sample_v;
	break;
	}//只取中心附近第一个符合行
// 扰动计算（核心修改部分）
if(closest_v > 0.0) {
float decay = 1.0 - min_dist/search_radius;
// 行随机方向控制
float row_hash = hash(closest_v, random_seed*2.34); //最近选中行的随机值
float dir;
dir = mix(-1, 1, row_hash); // 连续化随机方向

uv.x += max_offset * decay * dir;
}}
COLOR = texture(input_texture, uv);}