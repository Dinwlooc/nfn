shader_type canvas_item;
 
// 定义可外部控制的属性
uniform sampler2D texture1;
uniform sampler2D texture2;
uniform float blend_factor = 0.0;

 
void fragment() {
	vec4 current_color;
	vec4 from_color = texture(texture1,UV);
	vec4 to_color = texture(texture2,UV);
    // 使用线性插值计算当前颜色
    current_color = mix(from_color, to_color, blend_factor);
  	COLOR = current_color;
	}
	