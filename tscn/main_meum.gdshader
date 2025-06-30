shader_type canvas_item; // 声明这是一个用于2D渲染的着色器
 
// 定义可在Godot编辑器中调整的uniform变量
uniform sampler2D texture1;
uniform float range_min = -0.8;
uniform float range_max = 0;
uniform float luminance_max;
uniform vec4 color_offset = vec4(0.0, 0.1, 0.0, -1.0); // 颜色偏移量（RGBA）
uniform float glow_intensity = 0.30;
uniform float time;
uniform bool color_transition = false;
 
void fragment() {
    vec4 original_color = texture(texture1, UV); // 获取当前像素的原始颜色
    vec4 color = original_color;
    // 计算灰度值（使用亮度公式更准确）
    float luminance = dot(original_color.rgb, vec3(0.2126, 0.7152, 0.0722));
   // 初始化泛光颜色
    vec4 glow_color = vec4(0.0);
        // 定义采样偏移量（3x3邻域）
    vec2 offsets[9] = vec2[](
        vec2(-1.0, -1.0), vec2(0.0, -1.0), vec2(1.0, -1.0),
        vec2(-1.0, 0.0),  vec2(0.0, 0.0),  vec2(1.0, 0.0),
        vec2(-1.0, 1.0),  vec2(0.0, 1.0),  vec2(1.0, 1.0)
    );
    // 当中心像素亮度超过阈值时触发泛光
       float intermittent = (sin(time)+1.0)*glow_intensity;
        
        // 对3x3邻域进行采样计算泛光
    // 判断当前像素是否在指定区间内
   	 bool in_range = (luminance >= range_min) && (luminance <= range_max);
    // 检查邻域像素
    for(int i = 0; i < 9; i++) {
        vec2 sample_uv = UV + offsets[i] * TEXTURE_PIXEL_SIZE;
        vec4 sample_color = texture(texture1, sample_uv);
        
        // 计算邻域像素的亮度
        float sample_luminance = dot(sample_color.rgb, vec3(0.2126, 0.7152, 0.0722));
        
        // 如果中心像素或邻域像素满足条件，施加偏移
        if(color_transition&&(in_range || (sample_luminance >= range_min && sample_luminance <= range_max))) {
            color = original_color+color_offset;
			}
		if(sample_luminance>=luminance_max){
		glow_color = glow_color + sample_color * intermittent/8.0;
        }
    }
	glow_color.a = 0.0;
    color = color+glow_color;
    // 确保颜色值在有效范围内
   // color = clamp(color, vec4(0.0), vec4(1.0));
    
    COLOR = color; // 输出最终颜色
	}